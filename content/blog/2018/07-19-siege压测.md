---
title: siege压测

date: 2018-07-19

tags: [tools,net]

author: 付辉

---

关于压测，首先要了解`TPS`和并发用户数之间的关系：

> `TPS`就是每秒事务数，但是事务是基于虚拟用户数的。假如1个虚拟用户在1秒内完成1笔事务，那么`TPS`明显就是1；如果某笔业务响应时间是1ms，那么1个用户在1秒内能完成1000笔事务，`TPS`就是1000了；如果某笔业务响应时间是1s,那么1个用户在1秒内只能完 成1笔事务，要想达到1000`TPS`，至少需要1000个用户；因此可以说1个用户可以产生1000TPS，1000个用户也可以产生1000`TPS`，无非是看响应时间快慢。

针对上面的描述，引申出了命令的三个属性：

```
-c : This option allows you to set the concurrent number of users
-r : This option tells each siege user how times it should run.
-t : This option specify the number of times each user should run
```

对于`linux`的命令，其实`man`查看就足够了。

## `example`

提交`json`格式的数据请求到服务器。`POST`后跟数据内容，不需要使用引号处理。
```
# linux下执行命令
siege -f ./url.txt  -H "Content-Type: application/json"

# url.txt中的内容
HOST=neojos.com
$(HOST)/v1/buy POST {"bid": 0, "type": 13 }
```

