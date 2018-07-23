---
title: docker基本使用

date: 2018-04-20

categories: [2018-04]

tags: [tools]

author: 付辉

---

知道一点比完全不知道要好，对问题有深入了解比仅知道皮毛要好。作为`docker`的一个初学者，现在对`docker`做简单记录。希望随着工作、生活，更深入的了解学习`docker`。这也是一件很有意义的事。

`docker`有几个相关的概念：

1. `image` 镜像
2. `container` 容器

我觉得之所以说`docker`好用，是因为[`Docker Hub`](https://hub.docker.com/explore/)提供了很多镜像，比如`MySQL`、`Redis`等。对它们安装、卸载异常方便。

下面举个例子，我们想搭建测试服务，安装`MySQL`，`Redis`等依赖。我们将他们当作一个项目的依赖，声明一个配置文件·`db.yml`，然后将这些依赖，类似于`composer`编辑：

```
version: "3"

services:

  db:
    image: mysql:5.7
    volumes:
      - /Users/neojos/dockerData/mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: paytest
      MYSQL_DATABASE: paytest
      MYSQL_USER: neojos
      MYSQL_PASSWORD: neojos-pwd
    ports:
      - "3306:3306"

  myredis:
    image: redis
    restart: always
    volumes:
      - /Users/neojos/dockerData/redis
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
```

执行如下命令，`MySQL`和`Redis`的服务就启动了
```
docker-composer -f db.yml up
```

可以通过执行如下命令查看，确认是否有两个容器在运行。
```
docker container ls
```

这样很好，但当我想进去`MySQL`的容器内执行一些命令时，该怎么办呢？比如，我想确认下面的`MySQL`连接语句是否正确,而且我还一定要进去容器内执行`MySQL`命令行语句：

```
mysql -h 127.0.0.1 -P 3306 -u neojos -p'neojos-pwd' paytest
```

很简单,只需要执行如下指令。可以发现，已经进到`MySQL`命令行了。

```
docker container exec -it 9008f76b728d mysql -h 127.0.0.1 -P 3306 -u neojos -pneojos-pwd paytest
```

上面的命令可能看不太明白，所以我复制一下命令的说明：

```
See 'docker container exec --help'.

Usage:  docker container exec [OPTIONS] CONTAINER COMMAND [ARG...] [flags]
```

## `Dockerfile`指令

`Dockerfile`是一个文本文件，其内包含了一条条的指令(`Instruction`)，每一条指令构建一层，每一条指令的内容，就是描述该层应如何构建。

### `FROM`

所谓定制镜像，一定是以一个镜像为基础，在其上进行定制。而`FROM`就是用于指定基础镜像。因为`Dockerfile`中`FROM`是必备的指令，而且必须是第一条指令。

### `RUN`

新建一层，在其上执行命令。执行结束后，`commit`这一层的修改，构成新的镜像。

### `ENV`

用于设置环境变量：`ENV KEY VALUE`或者`ENV KEY=VALUE`

### `COPY`

将从构建**上下文目录**中源路径的文件/目录复制到新的一层的镜像内的目标路径的位置。

### `CMD`

指定默认的容器**主进程**的启动命令。容器就是进程，那么在启动容器的时候，需要指定所运行的程序及参数。

```
docker run image command
```
跟在镜像名后的是`command`，运行时会替换`CMD`的默认值。

### `ENTRYPOINT`

和`CMD`一样，都是指定容器启动程序和参数。当指定了`ENTRYPOINT`之后，`CMD`的含义就发生了改变，不再是直接运行其命令，而是将`CMD`作为参数传递给`ENTRYPOINT`指令。

### `EXPOSE`

声明运行时容器提供服务端口

### `WORKDIR`

用于指定工作目录，以后各层的当前目录就被改为指定的目录。如果目录不存在，系统会创建目录。

## 多阶段构建

原理：事先在一个`Dockerfile`将项目及其依赖编译测试打包好后，再将其拷贝到运行环境中。

主要使用的指令：

```
# 方便后续构建阶段引用
FROM image[:tag | @digest] AS stage

# 指明引用前面哪一个构建阶段的成果
COPY --from=stage ...
```

### `Example`
下面是精简版示例：
```
FROM registry.cn-beijing.aliyuncs.com/golang:1.10 AS build-env
ADD . /go/src/baby
WORKDIR /go/src/baby

RUN go build -x -o /build/baby main.go \
    && go build -x -o /build/task_monitor scripts/task_monitor/task_monitor.go \
    && go build -x -o /build/task_notify scripts/task_notify/task_notify.go 


FROM registry-internal.cn-beijing.aliyuncs.com/alpine:3.7
COPY --from=build-env /build/baby /data/src/baby
COPY --from=build-env /build/task_monitor /data/src/task_monitor
COPY --from=build-env /build/task_notify /data/src/iap_notify

COPY conf.simulation.toml /data/src/conf.simulation.toml
COPY conf.online.toml /data/src/conf.online.toml
COPY conf.test.toml /data/src/conf.test.toml

COPY docker/entrypoint.sh /data/src/

EXPOSE 3600

ENTRYPOINT ["/data/src/entrypoint.sh"]
CMD ["bash", "-c", "/data/src/${RUN_PROG:=baby} --log_dir=/data/logs/$RUN_PROG -c /data/src/conf.toml"]
```