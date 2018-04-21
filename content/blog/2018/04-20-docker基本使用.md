---
title: docker基本使用

date: 2018-04-20

categories: summarize

tags: [2018,tools,]

author: 付辉

---

知道一点比完全不知道要好，对问题有深入了解比仅知道皮毛要好。作为`docker`的一个初学者，现在对`docker`做简单记录。希望随着工作、生活，更深入的了解学习`docker`。这也是一件很有意义的事。

`docker`是提供了一个容器，有几个相关的概念：

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

可以通过执行如下命令查看，确实有两个容器在运行。
```
docker container ls
```

这样很好，但当我想进去`MySQL`的容器内执行一些命令时，该怎么办呢？

比如，我想确认一下我这样写`MySQL`的连接是否正确,我想进去容器内执行下面的指令：

```
mysql -h 127.0.0.1 -P 3306 -u neojos -p'neojos-pwd' paytest
```

很简单,只需要执行如下指令。可以发现，已经进到`MySQL`命令行了。

```
docker container exec -it 9008f76b728d mysql -h 127.0.0.1 -P 3306 -u neojos -pneojos-pwd paytest
```

上面的这个可呢个看不太明白，所以我复杂一下命令的说明：

```
See 'docker container exec --help'.

Usage:  docker container exec [OPTIONS] CONTAINER COMMAND [ARG...] [flags]
```
