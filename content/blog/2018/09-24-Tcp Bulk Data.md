---
title: Tcp Bulk Data

date: 2018-09-24

tags: [tcp/ip,net]

author: 付辉

---

`TCP`在数据传输中有`receive buffer`和`send buffer`。通过连接中的`window size`可以看出数据的读取情况。

## `sliding window`

`client`不需要等待已发送的`packet`的`ACK`，可以发送多个准备好的`packet`。换句话说，`server`端并不需要对每一个收到的`packet`，都执行`ack`操作。因为有缓冲去的存在，所以可以对收到的多个`packet`，统一回复一个`ack`。

## `window size`

通过握手，`TCP`两端交换`window size`的大小。`sender`可以连续发送多个`packet`来填满`receiver's window`，当应用层从`buffer`中读取数据之后，`window size`便会更新。比如，在`ack`的回复中，如果显示`win 0`，则表示`receiver`接收到了所有数据，但数据还在`buffer`中，尚未被应用读取。之后数据被读取，`window size`便会被更新，通过`ack`来重新通知`sender`。需要注意的是，该`ack`仅仅只是通知`window size`的更新。

对于`window size`，相关的是`sliding windows`。可以简单的想象成固定长度的“队列”，长度一定，表示`window size`是固定的。应用读取数据之后，队列末尾便会追加对应数量的`size`，供`sender`发送新的数据，队首的数据便彻底被移除了。

还有一点需要注意的：`client`端经常有数据需要发送，当收到`ACK`之后，`client`就会立即发送`buffer`中准备好的数据，应用端无法同时读取`buffer`中的数据来更新`window size`。所以，一般发送数据的`client`端的`window size`要比约定的小点。


## `PUSH`
`PUSH flag`这是`TCP header`中的一个标识，用于表示`sender`不想让该`packet`在`tcp buffer`中被缓存，去等待额外的数据到来，而是应立即传递给`receiver`处理。

## `slow start`
`sender`和`receiver`网络连接中可能存在很多`hop`或者`slower links`，这也就导致了`window size`确定的复杂性。这便引入了`congestion window`,术语`slow start`。`sender`在建立连接后，先初始化`window`为一个`segment`，每次收到`ack`，`sender`便增加一个`segment`（`exponential increae`），最终，`segment`的大小便是`congestion window size`。

## `Delayed Acks`

`sliding window`有效的提升了`TCP`的数据传输效率，使得接收数据的一端可以在收到多个`packet`后统一回复最后一个`packet`的`ACK`消息。发送数据的一端完全不需要等待数据被`ACK`之后，再才开始发送下一个`packet`。