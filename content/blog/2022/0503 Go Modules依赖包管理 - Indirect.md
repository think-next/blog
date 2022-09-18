---
title: "Go Module 依赖包管理 - Indirect"
date: "2022-05-03"
lead: "Indirect"
index: true
---

如果 go.mod 中包是间接依赖，会添加 // indirect 注释。原则上，go.mod 中出现都是直接依赖，为什么会出现间接依赖呢？

1. 直接依赖未启用的 Go Modules：如果模块A依赖模块B，模块B依赖模块B1和B2，但是B没有go.mod文件，则 B1和B2会记录到A的go.mod文件中，并在依赖最后加上 // indirect 注释
2. 直接依赖 go.mod 文件中缺失部分依赖：如果模块A依赖模块B，模块 B 依赖 B1 和 B2，B 有 go.mod 文件，但是只有 B1 被记录在 B 的 go.mod 文件中，这时候 B2 会被记录到 A 的 go.mod 文件中，并在最后加上// indirect。

如果我们要查看A项目的所有间接依赖，通过查看 A 项目中注释为 // indirect 的记录远远不够，因为还有很多间接依赖记录在直接依赖的 go.mod 中。

但 go.sum中记录了项目所有依赖的checksum值，通过查看 go.sum 可以来了解项目的所有依赖情况。当然，go 也有现成的命令用来查看项目依赖。

```
go mod why -m $path
```

下面使用第一版本的 bigcache 包作为例子，当时bigcache 还没有 go.mod文件

```go
package main

import (
	"fmt"
	"time"

	"github.com/allegro/bigcache"
)

func main() {
	cache, _ := bigcache.NewBigCache(bigcache.DefaultConfig(10 * time.Minute))

	cache.Set("my-unique-key", []byte("value"))

	entry, _ := cache.Get("my-unique-key")
	fmt.Println(string(entry))
}
```

我们查看 go.mod 文件，项目间接依赖了 testify 包，这是因为 bigcache 没有go.mod文件导致的。我们执行 `go mod why` 可以查看依赖使用情况。另外，我们还可以在项目中直接使用 testify 包，查看 go.mod 的变化情况

```
module local/awesomeProject

go 1.18

require github.com/allegro/bigcache v1.2.1

require github.com/stretchr/testify v1.8.0 // indirect
```