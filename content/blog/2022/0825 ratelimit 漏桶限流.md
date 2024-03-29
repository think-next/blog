---
title: "ratelimit 漏桶限流"
date: "2022-08-25"
lead: ""
---
限流的策略多种多样，比较常见、也容易理解的是计数器限流，计数器限流还有固定窗口和滑动窗口的区别，如果只是停留在理论的层面上，那就还只是思想层面的较量，只有落实到实际的代码中，才能对这套理论有更深的理解。这篇文章，不讲计数器限流，先通过ratelimit这个库，来对漏桶限流做基本的了解。

[ratelimit](https://github.com/uber-go/ratelimit) 拿来说，因为它足够简单，代码也没有那么多，跟写一个简单地算法题一样，不需要有什么特别的思路解法。漏桶限流的特点是：水从桶里面匀速的流出来，当桶满了的情况下，则拒绝请求。在设计代码的时候，如何考虑桶满的情况呢？当桶满的时候，是直接拒接请求还是让请求继续等待呢？水的匀速流出有该如何控制呢？

落实到具体的业务中，假设我们的请求处理效率是5QPS，也就是单机200ms处理一个请求，要达到这样的处理效果，我们大概会有下面几种考虑：

1. 我们单机通过一个全局变量来维护处理的信息，全局变量保存最近一次请求的时间。当新的请求进来时，尝试获取这个全局变量，读取最近一次处理请求的时间，如果间隔大于等于200ms，那就可以继续处理本次请求。如果没有，继续阻塞等待（或者直接返回）。
2. 我们预先按照200ms的间隔，把时间划分成块（类比一下，每1s就是一个时间快，200ms只是在1s的基础上有划分了5份），我们的全局变量中保存最近的块中是否已经处理过请求。如果新的请求进来，先判断它属于哪个时间块，然后判断时间块内是否处理过请求，如果没有处理过，就不处理，反之，继续处理请求。

如果要你自己实现简单的漏桶限流，你觉得上面的两种思路，哪个更适合你一些？我自己想了一下，使用第一种策略的话，保证了绝对的时间均匀，任意连续两个请求的时间间隔一定都大于或者等于200ms。第二种策略不会做到绝对的200ms内只处理1个请求。那么，ratelimit 是如何实现的呢？

这里插入一些题外话，注意区分单机限流和集中限流的区别，这篇文章主要用来说明单机限流。也不要因为划分200ms的间隔就和固定窗口限流搞混淆了，主要还是理解漏桶限流要解决的问题，实现方案其实多种多样的。

我截取 ratelimit 源码中的代码来理解。下面的 perRequest 代表 200ms，而它减去的时间就表示，这个时间块剩下的时间。

{{< highlight go "linenos=table,hl_lines=,linenostart=1,style=abap,lineanchors=neojos" >}}
newState.sleepFor += t.perRequest - now.Sub(oldState.last)
{{< / highlight >}}

oldState 就是我们提到的全局变量，last表示上一个请求的结束时间。每次都从上一次请求的结束时间开始计算时间块，比如，第一次请求时在50ms，然后100ms的时候来了第二个请求，按照我们的理论，以50ms开始等待200ms的时间去执行第二个请求，第二个请求需要等待 150 ms才可以继续执行。这样想的话，我们会按照下面的方式去计算等待的时间，为什么源码要使用 += 这个操作呢？

{{< highlight go "linenos=table,hl_lines=,linenostart=1,style=abap,lineanchors=neojos" >}}
waitMs := t.perRequest - now.Sub(oldState.last)
{{< / highlight >}}

这是一个数学计算式，`now.Sub(oldState.last)` 可能大于t.perRequest，也可能小于它。如果waitMs是一个正数的话，说明这两个请求时间相差200ms。如果waitMS是一个负数的话，说明已经超出了200ms，这时候使用负数的时间去执行Sleep操作，是不会发生阻塞的。

大家重新思考一下这个问题，我们每次都在执行完前一个请求后的200ms执行第二个请求，是不是有点时间浪费呢？按照时间块的理论，第一个请求是在第50ms的时候被处理（第一个时间块），第二个请求在100ms的时候到来，然后它需要等待150ms，也就是第250ms的时候会被处理。但是，第200ms的时候明明就是第二个时间块了，我们不等待那多余的50ms也是符合我们的设计预期的啊。话是这么说，但ratelimit却乜有这样实现。

ratelimit 引入了一个叫松弛量的概念，用来存储waitMS，为什么将这个变量存起来呢，主要是因为这个变量有负数的情况，这个负数的情况就好比“余钱”一样，可以抵消部分“债务”。比如说，还是上面的例子，第50ms的时候执行了第一个请求，第250ms的时候执行完了第二个请求，如果第三个请求时500ms来进来的话，程序计算等待的时间其实是 -50ms。如果第4个请求在来的话，可以借用这50ms抵消一部分的等待逻辑。而为了避免这个时间保留的过大，所以代码限制的最大值

{{< highlight go "linenos=table,hl_lines=,linenostart=1,style=abap,lineanchors=neojos" >}}
if newState.sleepFor < t.maxSlack {
	newState.sleepFor = t.maxSlack
}
{{< / highlight >}}

其他实现细节，大家可以去查看源码了解
