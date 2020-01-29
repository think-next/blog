---
title: HBase Region Split

date: 2019-02-22

tags: [think]

author: 付辉

---

> `Tables are automatically partitioned horizontally by HBase into regions. Each region comprises a subset of a table's rows`

## 引言

[`HBase`](https://hbase.apache.org/book.html)对`Table`提供了自动拆分的功能，非常好奇，它的自动拆分是如何实现的呢？在工作中，我们经常会遇到`MySQL`数据分表的情况，比如一个数据表已经超过`20G`了，查询耗时相对严重，我们考虑对其进行分表。又比如，我们预测每个月的交易流水会有几十亿条数据，我们按月对表进行拆分，等等。

`MySQL`提供了分区表，市面上也有很多的`Sharding`策略。但具体问题需要具体分析，分表策略也必须结合具体的业务来考虑。比如一个博客网站，用户主页需要展示他过去发布的所有博客列表，基于此，按照用户来分表就更为合理，保证同一个用户的所有数据都存储在同一张表里。

## `Concepts`

`HBase`中`column`被划分到一个`column family`里，所有的`column family`成员有一个唯一的前缀来标识。比如`info:190101`和`info:190102`就属于`info family`的的成员。有趣的是，虽然`column families`必须在表`schema definition`中被声明，但它的成员却是能够随意添加。

关于`Region`，作为分布式`HBase`集群数据的最小单元，每个`RegionServer`管理着`table regions`的若干个子集。客户端在和`HBase`交互时，都需要请求集群的`ZooKeeper`来获取集群的服务信息，缓存相关的元信息，之后就跟具体的`RegionServer`做交互了。

## `Reading Data`

专门去查看了`HBase`获取数据的方式，主要包括两种：

1. 获取行
2. 获取指定的列

相应的，我们需要了解它写入数据的方式：

```go
put ’<table name>’,’row1’,’<colfamily:colname>’,’<value>’
```

## `ConstantSizeRegionSplitPolicy`

`Region`有两个重要的属性`StartKey`和`EndKey`，用来表示`Region`维护的`RowKey`范围，当`Region Size`达到一定的阈值，`HBase`就会对其执行`split`操作，`Region`被划分为两个，其中一个`Region`，称呼为**`Region_1`**包含的`StartKey`到`MidKey`，另一个**`Region_2`**包含`MidKey`到`EndKey`的数据。这也引申出`HBase`的前缀范围查询的功能。

之所以可以这样划分，是因为`HBase`中数据行是以`RowKey`的字典序排列的，并且`RowKey`是全局唯一的。这样的划分策略对`RowKey`的设计有点需求，如果`RowKey`的随机性不好，在分布式集群中，负责`Region_1`的`RegionServer`负载和负责`Region_2`的负载相差可能会很多，导致资源的利用很不均衡。

其实也很好理解，就比如以中国的姓作为`RowKey`的前缀，那么负责“王、李”的`RegionServer`的负载就会很高，因为这些数据都会根据`StartKey-EndKey`写入到具体的`Region`上。很多时候，为了使数据分布的更加均匀，充分利用集群的资源，我们需要对原始的`RowKey`做一次`HASH`处理，在原始的`RowKey`和实际存储的`RowKey`之间生成一个固定的映射关系。

## `extension`

处理问题的思想都是相通的，比如`HBase`将数据存储到不同`Region`中。本质上也是：对数据进行分片，来扩展写操作。具体点就是：将数据划分成多个完全独立的子集，客户端通过映射关系，定向到具体的数据分片进行处理。

工作中接触最多的非`MySQL`莫属，如何对数据分片，根本还在于**业务最终要实现怎样的查询**。注意：设计中要尽量避免分片数据集的关联表查询，可能会有痛苦。



参考文章：

1. [HBase - Read Data](https://www.tutorialspoint.com/hbase/hbase_read_data.htm)