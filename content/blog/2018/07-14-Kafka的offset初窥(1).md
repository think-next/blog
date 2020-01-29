---
title: Kafka的offset初窥(1)

date: 2018-07-14

tags: [MQ]

author: 付辉

---

`kafka`适用的场景很多，但用它来`异步通知`却是让我略感头痛！

## 引言
对于`kafka`的`offset`问题，先从这篇文章说起：[How to disable auto commit?](https://github.com/bsm/sarama-cluster/issues/76) 它阐述了一个重要的信息：

> To disable auto-commit, simply delay your MarkOffset calls. A commit will only occur when the offsets have been changed. If you are not ready to commit, then don't mark the offset as ready.

对于其中的另一个建议：即由我们主动调用`consumer.CommitOffsets()`。当然它最后补了一刀：

> Auto commit gives us some trouble in this case, as we might commit offsets which we have not yet written to the database. Having the ability to disable it by simply setting config.Consumer.Offsets.CommitInterval = 0 would be great.

因为在`sarama/config`的校验配置中，做了如下的限制：当前库不支持手动提交`offset`:
```
switch {
	case c.Consumer.Offsets.CommitInterval <= 0:
		return ConfigurationError("Consumer.Offsets.CommitInterval must be > 0")
```
## 待解决的问题

常规来说，在调用第三方，完成支付时，采用的都是`http`异步通知的方式。即第三方不停的回调我们的接口，直到我们返回成功。或者，达到一个失败次数的阈值才停止。

但当前第三方重构，决定修改成发送`MQ`的方式。即支付成功之后，它只保证消息成功的被发送到了`kafka`。我们业务方订阅相应的`Topic`，来消费它推送的数据，去给用户添加权益。

当`Consumer`收到消息后，我们需要做一些本地的业务操作，比如写数据库。之后才能`MarkOffset`这条数据。但我们的操作绝对不可能100%成功，如果在`MarkOffset`前，某一步出错了，我们就直接返回。我们认为**kafka还会给我们重新推送这条处理失败的消息**。

测试的结果让我头疼：

1. 无法确定它下次尝试推送的时间
2. 无法确定它是不是100%都会推送

## 方案可行性

查阅了部分博客，感觉方案应该可行：**只要不提交消息的`offset`，消息还会被重复推送**。至少很多人也这么搞过，呵呵！比如下适用`Kafka`实现的一个分布式`DelayQueue`的介绍：

>Each produced message should have a timestamp at which it was pushed to the queue. At the
>consumer side, fetch a message from a partition and compare the message timestamp with system's timestamp to see if enough time has passed for you
>to process the message. If enough time has passed, process the message and commit the message's offset otherwise make sure you do not commit the
>offset.

因为我们之前也这样搞过！但这种方案不好，效率比较低，不如考虑`redis的Zset`来实现。当然，`zset`这也是我们后来采取的方案。

## 了解`kafka`
### `consumer`使用`pull`拉取数据

>Kafka follows a more traditional design, shared by most messaging systems, where data is pushed to the broker from the producer and pulled from the broker by the consumer.

### `consumer position`

> What is perhaps not obvious is that getting the broker and consumer to come into agreement about what has been consumed is not a trivial problem. If the broker records a message as consumed immediately every time it is handed out over the network, then if the consumer fails to process the message (say because it crashes or the request times out or whatever) that message will be lost. To solve this problem, many messaging systems add an acknowledgement feature which means that messages are only marked as sent not consumed when they are sent; the broker waits for a specific acknowledgement from the consumer to record the message as consumed. This strategy fixes the problem of losing messages, but creates new problems. First of all, if the consumer processes the message but fails before it can send an acknowledgement then the message will be consumed twice. The second problem is around performance, now the broker must keep multiple states about every single message (first to lock it so it is not given out a second time, and then to mark it as permanently consumed so that it can be removed). Tricky problems must be dealt with, like what to do with messages that are sent but never acknowledged.

>Kafka handles this differently. Our topic is divided into a set of totally ordered partitions, each of which is consumed by exactly one consumer within each subscribing consumer group at any given time. This means that the position of a consumer in each partition is just a single integer, the offset of the next message to consume. This makes the state about what has been consumed very small, just one number for each partition. This state can be periodically checkpointed. This makes the equivalent of message acknowledgements very cheap.

### `offset earliest and latest`的区别

> It can read the messages, then save its position in the log, and finally process the messages. In this case there is a possibility that the consumer process crashes after saving its position but before saving the output of its message processing. In this case the process that took over processing would start at the saved position even though a few messages prior to that position had not been processed. This corresponds to "at-most-once" semantics as in the case of a consumer failure messages may not be processed.

> It can read the messages, process the messages, and finally save its position. In this case there is a possibility that the consumer process crashes after processing messages but before saving its position. In this case when the new process takes over the first few messages it receives will already have been processed. This corresponds to the "at-least-once" semantics in the case of consumer failure. In many cases messages have a primary key and so the updates are idempotent (receiving the same message twice just overwrites a record with another copy of itself).

### `Offsets.Retention`配置属性

>The Kafka cluster durably persists all published records—whether or not they have been consumed—using a configurable retention period. For example, if the retention policy is set to two days, then for the two days after a record is published, it is available for consumption, after which it will be discarded to free up space. Kafka's performance is effectively constant with respect to data size so storing data for a long time is not a problem.