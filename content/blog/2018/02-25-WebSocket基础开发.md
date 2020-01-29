---
title: WebSocket基础开发

date: 2018-02-25

tags: [protocol]

author: 付辉

---

WebSocket是一种网络通讯协议。在服务器端可以将HTTP请求升级为WebSocket请求。区别于普通的HTTP请求，WebSocket中存在特殊的字段标识：

```
GET /chat HTTP/1.1
Host: server.example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==
Sec-WebSocket-Protocol: chat, superchat
Sec-WebSocket-Version: 13
Origin: http://example.com
```

这种协议升级，是在应用层实现的。所以一个服务器本身既可以提供WebSocket服务，也可以提供正常的HTTP服务。

我们下面对服务做区分。`/ws`负责对外提供WebSocket服务。
```
http.HandleFunc("/", serveForHttp)
http.HandleFunc("/ws", serveForWs)
```

将HTTP请求升级为WebSocket请求,处理连接的读写操作：
```
func serveForWs(w http.ResponseWriter, r *http.Request) {
    if r.Method != "GET" {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }
	
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        log.Println(err)
        return
    }
    
    go client.write()
	go client.read()
}
```

[Upgrader](https://godoc.org/github.com/gorilla/websocket#Upgrader.Upgrade)负责连接升级，同时指定连接的部分属性。包括`ReadBufferSize`，`WriteBufferSize `，`CheckOrigin`等。`Upgrader`默认会检查`header`头中`Origin`是否有效，如果你要使用这个默认函数的话，需要确保客户端请求头中包含`Origin`。

```
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}
```

具体[请求流程](http://blog.csdn.net/huwh_/article/details/76383208)：`Client`端`Dial`到`Server`，`Server`端`Accept`这个`sock`连接后，底层`go`出一个协程，负责升级成`WebSocket`协议，进行读写等操作。

从WebSocket中读取数据。WebSocket支持的数据类型有两种，分别是UTF-8编码的文本消息和二进制消息。当读消息异常时，可能是客户端将Sock关闭的原因或者其他，我们需要将它从内存的记录中删除掉。

```
defer room.hub.unregister <- c

mt, data, err := ws.ReadMessage()
if err != nil {
    if err == io.EOF {
        l.Info("Websocket closed!")
    } else {
        l.Error("Error reading websocket message")
    }
    break
}
```

WebSocket支持三种[控制消息](https://tools.ietf.org/html/rfc6455#section-5.5.1)，分别是：`close`, `ping`和`pong`。`ping`和`pong`出错时，我们需要`close`掉连接。`ping/pong`有效的避免了通讯过程中，因为中间节点问题，导致链接异常的情况。

我们还对所有的写操作，设置了过期时间点。当写操作超时时，链接应该被销毁、关闭。

```
func ping(ws *websocket.Conn, done chan struct{}) {
    ticker := time.NewTicker(pingPeriod)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C:
            if err := ws.WriteControl(websocket.PingMessage, []byte{}, time.Now().Add(writeWait)); err != nil {
                log.Println("ping:", err)
            }
        case <-done:
            return
        }
    }
}
```

H5并没有提供`ping/pong`的API，`pong`是由浏览器发起的。对于`pong`消息,我们不需要做任何处理。
```
c.conn.SetReadDeadline(time.Now().Add(pongWait))
c.conn.SetPongHandler(func(string) error { c.conn.SetReadDeadline(time.Now().Add(pongWait)); return nil })
```

WebSocket支持UTF-8编码的文本消息、及二进制消息。

## 模拟聊天室

在聊天室的应用中，需要保存所有在线用户的连接信息，我们引入`room`的结构。当用户进入`room`时，保存连接。当用户离开`room`时，取消连接。这些数据均保存在内存中。
```
type room struct {
	ID         string
	clients    map[*Client]bool
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
}

type Client struct {
	room *Room
	conn *websocket.Conn
	send chan []byte
}
```

Room主要提供注册、取消注册和广播消息的功能。也是一个后台运行的常驻协程。
```
func (room *Room) Run() {
    for {
    	select {
    	case client := <-room.register:
    		room.clients[client] = true
    	case client := <-room.unregister:
    		if _, ok := room.clients[client]; ok {
    			delete(room.clients, client)
    			close(client.send)
    		}
    	case message := <-room.broadcast:
    		for client := range room.clients {
    			select {
    			case client.send <- message:
    			default:
    				close(client.send)
    				delete(h.clients, client)
    			}
    		}
    	}
    }
}
```

接下来，我们需要管理各个房间。引入`Hub`的结构，主要负责房间的创建、房间的取消及为指定房间广播消息。
```
type Hub struct {
	rooms       map[string]*Room
	register    chan *Client
	unregister  chan *Client
}
```

所有暴露对象的地方，采用单利模式。保证在并发情况下，实例被初始化一次。这里充分利用Go中`once.Do`仅执行一次的特性，将代码简化到最佳。

```
var hub *Hub
func GetInstance() *Hub {
    once.Do(func() {
    	//init hub
    })
    return hub 
}
```

## 部署WebSocket集群服务

当WebSocket部署到多台服务器时，同一个房间内的用户就会连接到不同的服务器。所以，每台服务器都只是保存了房间的部分连接。这样可以有效的降低单机负载，及避免单点问题。

当系统决定对某个房间进行`广播`时，需要保证每台WebSocket服务器同时对该房间的用户进行广播。这涉及到WebSocket服务的水平扩展问题，也可以抽象为：不同服务间该如何通讯？

我们引入`pub/sub Broker`，用它来负责各个WebSocket服务间的通讯。这样的工具其实很多，比如`Redis`、`NSQ`、`Kafka`等。下面先介绍`Redis`的发布订阅功能。

### Redis的发布/订阅

利用Redis[发布/订阅](http://redisbook.readthedocs.io/en/latest/feature/pubsub.html)模式，每台WebSocket服务后台常驻一个协程，用来接收后台发布的消息。Redis订阅后会接收三种类型消息：错误消息、发布的消息及订阅`Channel`的消息。

采用这种方式会存在丢数据的情况。比如，`Client`订阅某个`Channel`后，该连接会一直挂着，等待接收订阅的消息，直到连接超时或异常断开。当连接超时时，我们需要重新发起订阅。但就在这个间隙`PUBLISH`的数据，永远也找不回来了。我们需要加一个`ping/pong`检查，以及持久化Redis `PUBLISH`消息的代码补丁。

```
psc := redis.PubSubConn{Conn: c}
if err := psc.Subscribe(redis.Args{}.AddFlat(channels)...); err != nil {
    return err
}

done := make(chan error, 1)
go func() {
    for {
        switch n := psc.Receive().(type) {
        case error:
            done <- n
            return
        case redis.Message:
            if err := onMessage(n.Channel, n.Data); err != nil {
                done <- err
                return
            }
            
            //TODO：广播消息
        case redis.Subscription:
            switch n.Count {
            case len(channels):
                if err := onStart(); err != nil {
                    done <- err
                    return
                }
            case 0:
                done <- nil
                return
            }
        }
    }
}()
```

## 连接断开到重连的数据处理

如果某个时刻，`Client`突然断开了连接，过了一会又重新连接上了,那么中间推送的数据如何处理？

这涉及是消息的持久化问题，以及消息推送的数据结构。每次推送的数据中都携带当前时间戳信息，当`Client`重新连接到服务时，需要携带最后一次接受到消息的时间戳。这样服务端只需要推送这段时间内的消息就OK了。

## 用户与用户间的相互通讯

当两个用户连接到同一台服务器上时，实现两者之间的通讯比较容易。但我们引入了WebSocket集群。

我们创建用户和服务器的关联关系，通过用户查找当前所在的服务器。这样通过服务器内存中的MAP映射关系，就可以操作用户的WebSocket连接了。

或许，我们还可以充分利用`Pub/Sub`的思路。每个`Client`都订阅一个唯一的`Channel`，这样可以很轻松的确保两个用户的通讯。哈哈，但还必须要考虑`Sub`所创建的链接数、文件描述符是否够用、并发。

参考文章：

>1. [websocket repository](https://github.com/gorilla/websocket/tree/master)
>2. [go-websocket-chat-demo](https://github.com/heroku-examples/go-websocket-chat-demo)
>3. [websocket godoc](https://godoc.org/github.com/gorilla/websocket)
>4. [websocket rfc6455](https://tools.ietf.org/html/rfc6455#section-5.5.1)
>5. [redis godoc](https://godoc.org/github.com/garyburd/redigo/redis#PubSubConn)



