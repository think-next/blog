---
title: "sentinel 计数器限流"
date: "2022-08-29"
lead: ""
draft: false
---

首先了解一下固定窗口限流，根据 QPS 将时间划分为若干块，比如说，100的 QPS，将每秒划分为 2 个时间块，第 1 个时间块进来 20 个请求，第 2 个时间块进来 80 个请求，刚刚好符合 100 QPS 的限制。紧接着第 3 个时间块进来 80 个请求，第 4 个时间块进来 20 的请求，按绝对的秒来看待这个问题，确实符合预期，但相对的来看，第 2 个时间块和第 3 个时间块也是 1 秒，但处理了 160 个请求。

滑动窗口限流就是通过相对的时间块来统计请求，还拿上面的例子，如果请求进到了第 3 个时间块，它计算当前 QPS 的机制是向前找对应的时间块，因为两个时间块表示 1 秒，而第 2 个时间块已经有 80 个请求了，所以，第 3 个时间块最多只能加到 20 ，再多的请求进来就会被限制。

从绝对的时间分块和相对的时间分块上来解释固定窗口限流和滑动窗口限流，本质上，跟我上一篇说的漏桶限流也没有什么区别，思路都是一样的，不同的方式有不同的优势和劣势。

滑动限流的分块如何设计呢？

按照滑动的表面特征来看，我们在内存中声明一个全局数组，数组的每个元素代表一个时间分片，数组中元素的值为当前时间分片内的请求数量。当新的请求进来时，我们确定当前请求所对应的数组元素下标，并且向前累加限制的元素数量，判断是否达到限流阈值。确定当前的这个请求属于哪一个时间分片，对应的是数组的哪一个下标，这个对应关系非常重要。

依据结合上面的例子，我们使用 2 个滑动分片，所以，声明数组的长度是 2。要确认当前的请求属于哪个分片，我理解主要考虑边界划分。继续上面的例子，第 1 个时间块的区间是 [1,500] 毫秒，第二个时间块的区间是 [501,1000] 毫秒，bucketLengthInMs 表示的便是每个时间块的长度 500 ms，而截止到现在时间可以拆分成 timeId 个时间块。如果第一个时间块的下标是0，那么当前请求所在的下标就是 timeId 了。又因为我们数组只维持两个时间分片，所以，用 timeId 对数组长度取余，就可以确定当前时间所属的数组下标。

{{< highlight go "linenos=table,hl_lines=,linenostart=231,style=abap,lineanchors=neojos" >}}
func (la *LeapArray) calculateTimeIdx(now uint64) int {
    timeId := now / uint64(la.bucketLengthInMs)
    return int(timeId) % la.array.length
}
{{< / highlight >}}

因为数组被设计成固定长度，所以，新的时间片生成时需要重写旧的时间片，侧面来说，它属于 LazyMode 的模式，通过请求被动触发生成新的分片。比如方，在[1, 1000]毫秒时间段内都是请求了，数组中保持了这两个分片的数据，但之后过了5000ms才有新的请求进来，那么新的分片就需要重新旧的分片。如何区分分片的新旧呢？通过分片的开始时间来做区分。当有新的请求的时候，我们计算当前分片的开始时间：

{{< highlight go "linenos=table,hl_lines=,linenostart=50,style=abap,lineanchors=neojos" >}}
func calculateStartTime(now uint64, bucketLengthInMs uint32) uint64 {
    return now - (now % uint64(bucketLengthInMs))
}
{{< / highlight >}}

既然将1秒的时间拆分成了2个分片，是如何统计这2个分片的和呢？因为分片的时间可能不是连续的，所以首先就需要确保分片的时间是连续的。我们只需要通过当前分片，向前找连续的分片，然后对请求数累加就可以。判断数组中的分片是否有效，使用的就是分片的开始时间：

{{< highlight go "linenos=table,hl_lines=,linenostart=257,style=abap,lineanchors=neojos" >}}
// ValuesConditional returns all buckets of which the startTimestamp satisfies the given timestamp condition (predicate).
// The function uses the parameter "now" as the target timestamp.
func (la *LeapArray) ValuesConditional(now uint64, predicate base.TimePredicate) []*BucketWrap {
    if now <= 0 {
        return make([]*BucketWrap, 0)
    }
    ret := make([]*BucketWrap, 0, la.array.length)
    for i := 0; i < la.array.length; i++ {
        ww := la.array.get(i)
        if ww == nil || la.isBucketDeprecated(now, ww) || !predicate(atomic.LoadUint64(&ww.BucketStart)) {
            continue
        }
        ret = append(ret, ww)
    }
    return ret
}
{{< / highlight >}}

数组中的每一个元素都是一个时间分片，依次拿出每一个元素，判断是否符合时间要求，然后返回符合时间要求的分片。 那我们例子来说，这个时间范围就是1秒，
通过当前时间计算当前的分片，然后向前推，总共跨越1秒的间距就可以。代码的注释写的也非常清楚。

{{< highlight go "linenos=table,hl_lines=,linenostart=57,style=abap,lineanchors=neojos" >}}
// getBucketStartRange returns start time range of the bucket for the provided time.
// The actual time span is: [start, end + in.bucketTimeLength)
func (m *SlidingWindowMetric) getBucketStartRange(timeMs uint64) (start, end uint64) {
    curBucketStartTime := calculateStartTime(timeMs, m.real.BucketLengthInMs())
    end = curBucketStartTime
    start = end - uint64(m.intervalInMs) + uint64(m.real.BucketLengthInMs())
    return
}
{{< / highlight >}}

总体来说，滑动窗口限流并不复杂，比较常规的计算逻辑。