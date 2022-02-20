---
title: "Go Plugin"
date: "2022-02-19"
lead: ""
---

> 有生之年，尽量低消耗地让肉身活着，享受简单本真的喜悦，接纳一切发生。尽量高消耗地让灵魂活着，学习、创新。然后干干净净离开

Go Plugin 使用上非常简单，将代码编译成一个 so 文件，在项目中 `Open` 它，通过 `Lookup` 查找其中的变量、方法，通过断言就可以直接使用。

项目做到一定程度便会尝试技术上的突破，Go Plugin 提供的插件机制能够将插件自动加载到主程序中。比如，我们在框架平台上提交编写好的 so 插件，主程序检测到新的 so 插件被加入，便主动执行这个插件，新的功能就生效了，整个流程不需要服务重新部署。

Plugin 可以应用在规则类的业务场景，比如要检测当前请求是否为黑产，需要从多个维度进行判断，对应的每个维度就可以抽象成插件，实现规则的自动加载。我们还可以将现有的业务做模块化划分，每个模块都对应一个插件，然后对插件做编排。

### 使用

首先，我们需要将模块代码编译成 so 文件。需要注意，入口文件需要在 mian 包下。通过给 build 追加一个编译属性，就可以编译出 so 文件了。

```go
go build -buildmode=plugin main.go
```

如何使用 so 文件呢？通过下面的例子来说明。

我们在插件中声明了 `init` 方法，用来帮助我们理解插件中 `init` 方法的执行顺序。同时，声明了一个 `duck.Duck` 类型的变量，变量 `Animal` 需要首字母大写才支持导出哦。

```golang
package main

import (
	"fmt"
	"github.com/think-next/lesson/plugin/duck"
)

func init() {
	fmt.Println("init .so")
}

var Animal = duck.Duck{}
```

我们看一下 duck 包的代码，duck 包中也声明了 `init` 函数，也是方便我们了解 `init` 的执行顺序。如果框架的代码也引用 duck 包的情况下，`init` 函数的执行情况是怎么样的？

为什么一定要将类型 Duck 放在一个新 `package` 下呢？既然是例子，简单点放在 mian 包下不行吗？Duck 的类型声明放到 main 包下确实不行。框架代码在 `Lookup` 到对象执行断言的时候，是无法访问 main 包下的类型的。这么说比较抽象，结合下文的示例继续说明。

```go
package duck

import "fmt"

func init() {
	fmt.Println("duck init")
}

type Duck struct {
	Name string
}

func (duck *Duck) PrintName() {
	fmt.Println(duck.Name)
}
```

我们写一下框架程序，代码主要用来解释 Plugin 的功能，所以将可能的 `error` 进行了忽略。框架程序展示了 Plugin 使用的基本模式。

1. 打开一个 so 文件
2. `Lookup` so 文件中声明的变量或者函数
3. 断言成具体的类型之后，就可以正常使用

这里重新解释将 Duck 放在新的 `package` 下的原因。因为框架程序执行断言，需要知道具体的类型，如果将 Duck 声明在 Plugin 的 main 包下，框架程序是无法访问的。

程序第9行我们打开插件，第10行我们查找 `Anminal` 变量，第11行我们直接将它断言成 `duck.Duck`类型，之后就是对 `duck.Duck` 的直接使用了

{{< highlight go "linenos=table,hl_lines=0,linenostart=1,style=black,lineanchors=neojos" >}}

package main

import (
	"github.com/think-next/lesson/plugin/duck"
	"plugin"
)

func main() {
	p, _ := plugin.Open("/Users/fuhui/Code/src/github.com/think-next/lesson/plugin/main.so")
	v, _ := p.Lookup("Animal")
	animal := v.(*duck.Duck)
	animal.Name = "my name is duck"
	animal.PrintName()
}
{{< / highlight >}}


本质上，我们可以将 so 插件作为项目的一个普通 `package` 来对待，只是我们缺少一个明确的 `package path` 来 `import` 它，我们需要按照 Plugin 的提供的方式来引用它。因为缺少 `package path`，插件内部的类型声明对外部来说，就是一个黑盒。

关于 `init` 的初始化顺序，插件在被 `Open` 的情况下，插件 `main` 包下的 `init` 才会执行。那 `duck` 包呢，就需要具体情况具体分析。如果框架中已经使用到了，在插件被 `Open` 的时候就不会被执行了。

