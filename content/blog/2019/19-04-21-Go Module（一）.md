---
title: Go Module（一）

date: 2019-04-21

author: 付辉
---

> `这世上太多的人，宁愿吃生活苦，也不愿吃自律的苦。大概是因为生活的苦，躺着就来了，而自律的苦，得自己去找。但只有吃得下自律的苦，才有成功的自由，没有一种成功是走得了捷径的，通向真正成功的唯一道路只有自律。越成功，越自律。越自律，越成功。`

## `GO111MODULE`

`Go 1.1`包含了对`Go Modules`的[预支持](<https://golang.org/cmd/go/#hdr-Preliminary_module_support>)，包括调整后的`go get`命令。后续版本总`GOPATH`和老的`go get`可能会被官方移除。

在`Go Modules`中支持了一个临时环境变量：`GO111MODULE`，可以赋值为`off`、`on`或`auto`。

1. 值为`off`，表示不支持`Go Modules`模式，`Go`仍然在`vendor`和`GoPATH`路径下查找依赖；
2. 值为`on`，表示当前明确使用`Go Modules`，`Go`不再去`GOPATH`下查找任何依赖；
3. 值为`auto`或未设置，表示是否启用`Go Modules`依赖当前的目录情况，当编译的项目在`GoPATH/src`之外，或者当前目录或子目录本身包含`go.mod`文件，则启用`Go Modules`模式。

## `Defining a module`

`module`通过源码根目录下的`go.mod`文件来[定义](<https://golang.org/cmd/go/#hdr-Defining_a_module>)。根路径下的`module`是项目依赖包的集合，但会排除子目录的`go.mod`文件。

下面是`go mod`文件模版：

```go
module example.com/m

require (
	golang.org/x/text v0.3.0
	gopkg.in/yaml.v2 v2.1.0
)
```

要开始使用`go mod`，仅需要在项目下执行`go mod init`命令创建`go.mod`文件即可。

```shell
go mod init example.com/m
```

## `The go.mod File`

`go.mod`文件的每一行都包还一个简单的指令(`module`、`require`、`exclude`、`replace`)，然后紧跟参数部分。指令除了单行表示之外，还可以是一个块的形式。其中，文件也是以`//`作为注释符。

下面是截取我项目下的`go.mod`文件的部分内容：

```go
module gitlab.luojilab.com/igetserver/order_delivery

go 1.12

require (
	github.com/Shopify/sarama v1.22.1
	github.com/bsm/sarama-cluster v2.1.15+incompatible
	github.com/golang/glog v0.0.0-20160126235308-23def4e6c14b
	github.com/gopherjs/gopherjs v0.0.0-20181103185306-d547d1d9531e // indirect
)

replace (
	cloud.google.com/go => github.com/GoogleCloudPlatform/google-cloud-go v0.36.0
	github.com/ugorji/go => github.com/ugorji/go/codec v0.0.0-20190204201341-e444a5086c43
	golang.org/x/text => github.com/golang/text v0.3.0
)
```

`go.mod`中依赖库的版本标签都类似`v.0.1.0`，其中打头的`v`是必须的，三个表示版本的数字也是被要求的。当然，并不是严格要求。

`go mod`比较推崇这个给版本打`release tag`的方式，比如我们文件中的`github.com/golang/text`，引用的版本被项目开发者明确的标记为`v0.3.0`。而它非常反对我们通过具体的`commit hash code`来引用一个具体的开发版本，所以，他有一套默认的版本机制，格式就是：`v0.0.0-yyyymmddhhmmss-commit`，从我们的`go.mod`文件中也可以看出来。

## [`Modules and vendoring`](<https://golang.org/cmd/go/#hdr-Modules_and_vendoring>)

当使用`module`时，`Go`命令会完全忽略`vendor`目录。为了跟之前`Go`的依赖管理相兼容，我们可以使用`go mod vendor` 创建`vendor`目录来存储编译代码的依赖包。如果在编译的时候要使用`vendor`中的依赖包，需要使用`go build -mod=vendor`命令。

```shell
go mod vendor 
go build -mod=vendor
```

## [`Go Get`](<https://golang.org/cmd/go/#hdr-Module_aware_go_get>)

首先，`go get`解析需要新增哪些依赖。可以通过在包名后添加`@version`或者`@branch`等方式来取代命令的默认更新行为。如果后缀指定为`@none`，则表明该依赖应该被移除。

其次，`go get`会下载、编译、安装指定的包。包的安装模式也是被允许的，比如使用`go get golang.org/x/perf/cmd/..`来更新`cmd`下的所有子包。

```shell
go get -u <repo url>
go mod vendor
```
