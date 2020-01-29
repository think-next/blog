---
title: mongo EOF

date: 2019-04-27

author: 付辉
---
> `很多事情仅仅的是严肃的提出问题都感觉很难，更何况还得要先发现它。`

## `Question`

### 描述

项目中使用：[`github.com/globalsign/mgo`](https://godoc.org/github.com/globalsign/mgo)这个库，在一次主从切换之后，`mongo`后续的操作都失败了, 错误信息输出：`EOF`。

引用网上遇到[同样问题](https://groups.google.com/forum/#!topic/mgo-users/XM0rc6p-V-8)的其他描述：

> `The problem I have is, when the connection to the mongodb server fails (the server drops the connection sometimes or mongodb server fails), then my pointer to the session variable doesn't work anymore. Even if the internet connection comes back, mgo driver doesn't reconnect anymore, instead of this I get the error (when I do Find().One() method call): "EOF"`

### 解决思路

> 1. Call Refresh on the session, which makes it discard (or put back in 
the pool, if the connection is good) the connection it's holding, and 
pick a new one when necessary. 
> 2.  Instead of using a single session, use many by calling session.Copy 
when you need a new session, and then call session.Close when you're 
done with it. This will also mean you're using multiple connections to 
the database, when necessary. 

按照这个思路，在`mongo`启动的时候，设置一个定时`ping`检查。当`error`返回`io.EOF`时执行[`Refresh`](https://godoc.org/github.com/globalsign/mgo#Session.Refresh)操作。

**主从切换就会出现这个问题吗？发现并不是。下面的重现的尝试**

## 搭建[`replica set`](https://docs.mongodb.com/manual/reference/glossary/#term-replica-set)

参考这里[`Use only docker and docker-compose to create a MongoDB Replica Set`](https://github.com/yowko/Docker-Compose-MongoDB-Replica-Set)创建`docker-compose.yml`文件。

稍稍对文件做了修改，指定了`ports`命令，以达到本地可以访问容器内`mongo`的目。

## 测试

循环1000次来执行读操作，在读操作执行的过程中，关闭掉`PRIMARY`节点，强制触发主从选举。很遗憾，服务短暂不可用之后，恢复正常了

```go
type People struct {
	FirstName string `json:"firstname"`
	LastName  string `json:"lastname"`
}

func TestCheckComplete(t *testing.T) {
	session, err := mgo.DialWithTimeout("mongodb://127.0.0.1:27017,127.0.0.1:27018,127.0.0.1:27019/admin?replicaSet=rs0", time.Second)
	if err != nil {
		panic(err)
	}
	session.SetSyncTimeout(time.Second)

	var actionLog People
	for i := 0; i <= 1000; i ++ {
		// show progress
		fmt.Print(".")
		
		if err := session.DB("dev").C("people").Find(bson.M{"firstname": "Nic"}).One(&actionLog); err != nil {
			if err == io.EOF {
				fmt.Println("the error equal io.EOF")
			}
			if err.Error() == "EOF" {
				fmt.Println("the error.Error() equal io.EOF")
			}
			fmt.Println(err)
		}
	}
}
```
## `docker-compose.yml`

### `ports vs expose`

`ports`暴露容器端口到主机的任意端口或指定端口。当我们想在本地访问`docker`内服务时，就需要使用这个命令。比如：

```
ports:
  - "27018:27017"     # 绑定宿主27018端口端口到容器21017端口
```

`expose` 声明运行时容器打算使用的端口，这只是一个声明，在运行时应用并不会因为这个声明就会开启这个端口。只有在使用 `docker run -P` 时，才会自动基于规则映射`EXPOSE`的端口。

```
expose:
    - 27017
```

### `entrypoint`

`entrypoint`用于指定容器启动程序和参数。当指定了`entrypoint`之后，`cmd`的含义就发生变化了，不再是直接运行命令，而是将`cmd`的内容作为参数传递给`entrypoint`指令。这里的`cmd`主要代指容器名后面追加的参数。

```
<entrypoint> "<cmd>"
```

如`docker-compose.yml`中的示例代码，用于初始化`mongo`的配置。

```
creator:
    build: creator
    entrypoint: ["mongo","--host","mongo1","--port","27017","--eval", 'rs.initiate( { _id : "rs0",members: [{ _id: 0, host: "mongo1:27017" },{ _id: 1, host: "mongo2:27017" },{ _id: 2, host: "mongo3:27017" }   ]})']
    depends_on:
      - mongo1
      - mongo2
      - mongo3
```

### `depends_on`

`depends_on`用来定义服务间的依赖关系，`creator`要落后于`mongo1-3`的启动

## `docker command`

```
# 查看容器的日志
docker logs -f <container-id>

# 获取当前容器的信息
docker container ls -a

# 启动容器
docker-compose -f docker-compose.yml up

# 进去容器里面
docker exec -it <contrainer-id> bash

# 关闭容器
docker container stop <container-id>
```

## `mongo command`

> `A replica set in MongoDB is a group of mongod processes that maintain the same data set. Replica sets provide redundancy and high availability, and are the basis for all production deployments. This section introduces replication in MongoDB as well as the components and architecture of replica sets. The section also provides tutorials for common tasks related to replica sets.`

```
// Returns:	A document with status information.
// 查看当前mongo的主从节点配置
rs.status()

// This allows the current connection to allow read operations to run on secondary members.
// 当在SECONDARY节点上执行show dbs失败时执行
rs.slaveOk()
```
