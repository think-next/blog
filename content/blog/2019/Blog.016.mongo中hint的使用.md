---
title: mongo中hint的使用

date: 2019-11-13

tags: [mongo]

author: 付辉
---

`mongo`官方文档对`hint`的解释如下：

> The $hint operator forces the query optimizer to use a specific index to fulfill the query. Specify the index either by the index name or by document.

`hint`的命令行用法：
```
db.users.find().hint()
```

`mongo`中使用`explain`来确定查询使用的索引方案，对比`explain`的结果，可以反向校验`hint`的使用。`explain`的命令行用法:

```
db.collection.explain()
```

`github.com/globalsign/mgo`下对`hint`方法的注释如下：
```go
// Hint will include an explicit "hint" in the query to force the server
// to use a specified index, potentially improving performance in some
// situations.  The provided parameters are the fields that compose the
// key of the index to be used.  For details on how the indexKey may be
// built, see the EnsureIndex method.
```
`hint`参数列表是用作索引的字段，更多细节请参考`EnsureIndex`方法。

```
// To obtain an index with a descending order,
// the field name should be prefixed by a dash 
```

组合索引

`mongo`中组合索引称为[`Compound Index`](https://docs.mongodb.com/manual/indexes/#compound-index)，不同于`MySQL`，它可以指定索引字段排列顺序。对于下面的索引：

```
{ userid: 1, score: -1 }
```

索引先通过`userid`进行排序，如果`user_id`相同，再根据`score`的倒序排。这中形式，对查询有什么影响呢？

从`mongo`官方文档的例子来尝试理解，索引`{ a: 1, b: -1 }`支持`{ a: 1, b: -1 }`和`{ a: -1, b: 1 }`的排序操作，但不支持`{ a: -1, b: -1 } `和`{a: 1, b: 1}`的操作。

