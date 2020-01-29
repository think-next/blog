---
title: xorm使用reverse指令创建模版

date: 2018-04-19

tags: [golang]

author: 付辉

---

这只能算作一次小的功能介绍

结合我们使用过的`go`数据操作类的库，执行的逻辑基本都是：将数据库返回的数据，转换成我们提前声明的结构体对象，然后返回。

今天要介绍的就是如何自动创建每个`table`对应的结构体。

查看 [xorm tool](http://xorm.io/docs/)的介绍：

```
xorm reverse mysql root:@/xorm_test?charset=utf8 templates/goxorm
```

初看这个介绍，让我费了一段时间才理解。你可以在命令行查看它的具体含义：

```
xorm help reverse
```

命令中`templates/goxorm`其实是`xorm`提供好的模版路径。我错误的理解成了：执行命令生成结果的存储路径。

```
tmplPath          Template dir for generated. the default templates dir has provide 1 template
```

其次就是`mysql`的连接语句：一般来说，都是这样写的：
```
username:pwd@ip:port/db?charset=utf8
```

但是使用上述方式却无法正常执行命令，正确的方式是：
```
xorm reverse "username:pwd@tcp(ip:port)/db?charset=utf" templates/goxorm 
```

