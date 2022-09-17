---
title: "Go Module 依赖包管理 - Replace"
date: "2022-05-02"
lead: "replace"
index: true
---

module 用来定义当前项目的模块路径，这个路径会作为其他命令路径的参考。比如，replace 命令指定模块到本地的时候，使用的相对路径就是模块路径。

replace 用来将一个模块替换成另外一个模块版本，格式为 $module => $newmodule。除了手动编辑 go.mod 文件外，还可以在命令行输入编辑指令

```
go mod edit -replace $module=$newmodule
```

replace 的目标路径形式比较多，可以指定到项目本地路径，也可以是网络的路径。在本地调试一些依赖包的时候，就可以将依赖包下载到项目中，通过 replace 来替换网络地址

我们通过一个例子来说明，我们项目本地依赖了 lru 缓存，main 函数的逻辑：

```go
package main

import (
	"fmt"

	"github.com/golang/groupcache/lru"
)

func main() {
	cache := lru.New(1)
	fmt.Println(cache.Len())
}
```

对应的 go.mod 文件内容如下，如果我们想要调试 groupcache 包，第一步将 groupcache 包下载到本地，第二步增加 repace 命令替换当前 require 中的代码包。第三步直接调试本地 groupcache 包就可以啦

```
module local/awesomeProject

go 1.18

require github.com/golang/groupcache v0.0.0-20210331224755-41bb18bfe9da
```