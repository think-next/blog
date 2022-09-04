---
title: "Dockerfile ENTRYPOINT 原语"
date: "2022-09-04"
lead: ""
---
Dockerfile 中会包含 Shell 命令，Shell 命令中自定义变量的解析，有时候没有按照预想的方式进行。发生这种问题是什么原因呢？

我们用一个简单的Dockerfile文件来说明这种情况，查看执行输出的结果。我们创建一个空的文件夹，声明一个 Dockerfile 文件，文件的内容简化如下。然后，进去这个目录，将Dockerfile编译成一个镜像。

```dockerfile
FROM ubuntu:latest

CMD ["/bin/sh", "echo neojos"]
```

编译镜像的过程只需要执行下面的命令，通过 -t 我们给镜像起一个容易识别的名字，官方的解释是起一个 Tag。之后我们就启动这个镜像的容器，观察输出结果。

```shell
docker build -t test .
docker run test
```

很遗憾，这样执行最终会报错，我预期就是输出 neojos 这个字符串，但是指令报错了。我试着将Dockerfile 修改成了下面这个样子，然后控制台正常的输出了 neojos 字符串。所以，最终执行的时候，其实是在控制台执行了一条 `/bin/sh -c "echo neojos"` 的命令。

```shell
FROM ubuntu:latest

CMD ["/bin/sh", "-c", "echo neojos"]
```

如果我在指令中使用Shell 的变量声明，就是将例子中的 neojos 作为一个变量进行传递。怎么在 Dockerfile 语法书
