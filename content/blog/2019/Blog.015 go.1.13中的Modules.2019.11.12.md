---
title: go.1.13中的Modules

date: 2019-11-12

tags: [golang]

author: 付辉

---

环境变量`GOPRIVATE`

`GOPRIVATE`升级到`go.1.13`不得不调整的一个变量。表示引用到的`modules`是私有的，无须从`proxy`下载，也无须校验包的`checksum`。

公司内部基本都有自己的`git`仓库，升级为`go.1.13`后，需要在`GOPRIVATE`中设置仓库的通配符地址。如果不设置该环境变量，`go`加载`package`时会从`GOPROXY`获取，而默认的`GOPROXY`无法找到指定的包。

参考官方提供的例子：
```bash
GOPRIVATE=*.corp.example.com,rsc.io/private
```

环境变量`GOPROXY`

`go.1.13`默认将`GOPROXY`设置为`https://proxy.golang.org,direct`，但执行`go get`会发现，这个地址是无法使用的。

从官方的提供的例子中，简单了解`GOPROXY`的规范：
```bash
// returns a list of all known versions of the given module, one per line.
GET $GOPROXY/<module>/@v/list
```

当通过`GOPROXY`找不到具体的`module`时，会看到404或401的状态码

如果就是很烦躁，也可以不使用这个环境变量:
```basg
export GOPROXY=off
```