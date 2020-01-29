---
title: Saga Pattern

date: 2018-04-24

tags: [transaction]

author: 付辉

---

在微服务中，用的比较多的分布式事务模式：[`SAGA`](https://www.cs.cornell.edu/andru/cs711/2002fa/reading/sagas.pdf)。下面是`lysu/go-saga`库中的描述：

> Saga is a long-lived transaction came up with many small sub-transaction.ExecutionCoordinator(SEC) is coordinator for sub-transactions execute and saga-log written.Sub-transaction is normal business operation, it contain a Action and action's Compensate. Saga-Log is used to record saga process, and SEC will use it to decide next step and how to recovery from error.Log presents Saga Log. Saga Log used to log execute status for saga, and SEC use it to compensate and retry.

## 引言
`saga`是一个本地事务的序列，每个事务都在各个微服务内部完成。通过外部的请求来开始第一个事务，且当前面的事务完成后，后面的事务就会被触发。

它的核心思想：

1. 将事务进行拆分，划分成更小的事务粒度。
2. 补偿逻辑。对失败的事务进行补偿

简要描述一下：

```
# 中心系统 - 充当分布式事务管理中心
1. 请求 - 订单服务 - 用户下单
2. 请求 - 库存服务 - 减少库存
```

下面介绍实现`saga`最流行的两种方式：

1. `Events` 不需要一个中心调度系统，每个服务生产、监听别的服务产生的事件，决定下一步怎么处理。
2. `Command` 有一个中心服务来协调管理业务逻辑，做`saga`决策。

## `Events`

在`Events`的方式中，各个服务执行完成事务之后，会发布一个`event`。其他服务会监听这个`event`，然后执行自己本地的事务，发布一个新的`event`。

当最后一个服务执行了本地事务，没有发布新的`event`,或者发布了其他服务不监听的`event`。分布式事务终止。

对这种方式来说，有效跟踪事务的执行状态是一个痛点。但实际工作中，确实需要明确知道事务的执行路径。两种解决办法：

1. 每个服务都更新当前的事务记录，记录可以存储在`DB`中，有几个服务，记录就应该有几个状态。
2. 插入一个服务，监听所有服务的`event`。

### 补偿逻辑

分布式事务执行过程中，当其中一个事务执行失败之后，事务需要触发补偿逻辑。其原理还是发送一个`event`，只不过其他服务监听到之后，处发事务的补偿逻辑，回滚之前的本地操作。

### 实现方式

采用消息队列实现，以`NSQ`为例，可以这样考虑：

1. `event`应该有一个唯一的身份标识。
2. 每个服务至少应该监听一个`topic`，且至少作为一个`topic`的`producer`。
3. 可以考虑一个统一的`topic`，多个`channel`的实现方式。

### 总结

当服务比较多的时候，`topic`可能会有很多，程序复杂性提高了不少。而且，一个留神，很可能让监听变成了一个死循环。

## `command`







