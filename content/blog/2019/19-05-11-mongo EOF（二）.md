---
title: mongo EOF（二）

date: 2019-05-11

tags: [golang, docker]

author: 付辉

---

> `任何事情的成功都需要掐准时间`



上一节`mongo EOF`中，关于容器的配置，只是粗略的使用了[`Docker-Compose-MongoDB-Replica-Set`](<https://github.com/yowko/Docker-Compose-MongoDB-Replica-Set>)项目提供好的`docker-compose.yml`文件。在使用过程中，我发现这个文件本身一些不如意的地方。首先，`services`中的`creator`服务，`entrypoint`指令太长了，不美；其次，所有的`service`都没有给容器外部暴露端口，导致外部无法访问容器；再次，直接使用`mongo repliSet`的连接串进行访问，无法正常访问`mongo`服务。 

在上一篇文章的基础上，这篇文章对`docker-compse.yml`做了一些调整，并且也包含了`docker`使用的入门介绍。更新后的`docker-compose.yml`请访问[githubsi](<https://github.com/GitHubSi/Docker-Compose-MongoDB-Replica-Set>)。

## depends_on

> However, for startup Compose does not wait until a container is “ready” (whatever that means for your particular application) - only until it’s running. [There’s a good reason for this](https://docs.docker.com/compose/startup-order/).

在`creator service`中使用了该指令， 但是，实际中`creator`不会等到`mongo1`、`mongo2`、`mongo3`容器`ready`后再启动，而是等到它们启动就开始启动。这也是我在`setup`脚本中执行`sleep`操作的原因。

```yml
creator:
    build:
      context: .
      dockerfile: dockerfile
    entrypoint: ["/data/conf/setup.sh"]
    depends_on:
      - mongo1
      - mongo2
      - mongo3
```



## entrypoint

> Entrypoint sets the command and parameters that will be executed first when a container is run.

entrypoint设置了容器启动时执行的命令和参数，传递给`docker run <image>`的参数都将追加到`entrypoint`命令之后，并且会覆盖`CMD`命令。比如，`docker run <image> bash` 将会追加`bash`到`entrypoint`命令末尾。

命令的语法格式：

```dockerfile
ENTRYPOINT ["executable" "param1" "param2"]
```

在修改后的`docker-compose.yml`中，`entrypoint`指令用于执行`shell`脚本。按照规范来说，可执行文件名称中需要包含`entrypoint`字段，也就是将下列指令中的`setup.sh`重命名为`setup-entrypoint.sh`。但是，重命名之后的文件，容器执行会报错，所以，这里也并没有使用这个规范。

```yml
entrypoint: ["/data/conf/setup.sh"]
```



## 调整`creator`中的`entrypoint`指令

原始的文件如下所示，`entrypoint`指令的参数非常难看：

```yml
creator:
    build: creator
    entrypoint: ["mongo","--host","mongo1","--port","27017","--eval", 'rs.initiate( { _id : "rs0",members: [{ _id: 0, host: "mongo1:27017" },{ _id: 1, host: "mongo2:27017" },{ _id: 2, host: "mongo3:27017" }   ]})']
    depends_on:
      - mongo1
      - mongo2
      - mongo3
```

如果将`entrypoint`的执行命令提取到一个单独的的脚本中，会让整个页面看起来更加简洁。所以，新建一个`setup.sh`文件。其中的[`replicaSet.js`](<https://github.com/GitHubSi/Docker-Compose-MongoDB-Replica-Set/blob/master/replicaSet.js>)用于执行`rs.initiate`操作，详情可以查看`github`项目。其中的`sleep`指令只是为了保证：在执行`initiate`时`mongo`的3个服务都启动了。

```shell
#! /bin/bash

echo "******************************"
echo Start the replica set
echo `date`
echo "******************************"

sleep 20 | echo Sleeping
echo `date`

mongo mongodb://mongo1:37017 replicaSet.js
```

相应的，我们需要调整`creator`的`dockerfile`文件，因为此时的容器内，并没有我们需要的相关文件。我们需要在创建镜像的时候，拷贝本地文件到容器。调整后的文件如下：

```dockerfile
FROM mongo:4.0.4

MAINTAINER Yowko Tsai <yowko@yowko.com>

WORKDIR /data/conf

COPY ./setup.sh /data/conf/setup.sh
COPY ./replicaSet.js /data/conf/replicaSet.js

CMD ["./setup.sh"]
```

在项目的目录下，我们单独编译`creator`的`dockerfile`文件，已保证调整是有效的。

```shell
docker build .
docker run <image>
```



## 容器访问

以`mongo1`为例，在原始的文件中，`docker-compose.yml`如下：

```yml
mongo1:
    container_name: mongo1
    image: mongo:4-xenial
    expose:
      - 27017
    restart: always
    entrypoint: [ "mongod", "--bind_ip_all", "--replSet", "rs0" ]
```

上面的配置，本地主机是无法访问容器的，我们至少需要暴露出一个端口。下面通过添加`ports`来指定容器外到容器内的端口映射。在[上一篇](<https://neojos.com/blog/2019/2019-04-27-mongo-eof/>)中已经介绍过`ports`和`expose`的相关内容，感兴趣的可以去查看。之后，我们就可以通过37017端口来访问容器内的`mongo1`服务了。

```yml
mongo1:
    container_name: mongo1
    image: mongo:4.0.4
    expose:
      - 37017
    ports:
      - "37017:37017"
    restart: always
    entrypoint: [ "mongod", "--port", "37017", "--bind_ip_all", "--replSet", "rs0" ]
```

查看[Default MongoDB Port](<https://docs.mongodb.com/manual/reference/default-mongodb-port/>)，`mongod`的默认端口其实是27017，而这里写成37017也是有原因的。未修改之前`mongod`的端口映射，如下所示。每个容器中的`mongo`服务都使用默认的27017端口，通过暴露不通的宿主主机端口来达到区分容器服务的目的。

```yml
mongo1:
    container_name: mongo1
    image: mongo:4.0.4
    expose:
      - 27017
    ports:
      - "27017:27017"
    restart: always
    entrypoint: [ "mongod", "--bind_ip_all", "--replSet", "rs0" ]
  mongo2:
    container_name: mongo2
    image: mongo:4.0.4
    expose:
      - 27017
    ports:
      - "27018:27017"
    restart: always
    entrypoint: [ "mongod", "--bind_ip_all", "--replSet", "rs0" ]
  mongo3:
    container_name: mongo3
    image: mongo:4.0.4
    expose:
      - 27017
    ports:
      - "27019:27017"
    restart: always
    entrypoint: [ "mongod", "--bind_ip_all", "--replSet", "rs0" ]
```

在单独连接`mongo`服务的时候，这样的配置是没有任何问题的。我们在命令行输入`mongo`，也会连接到其中任意一个`mongo`服务。如果恰好连接的不是`PRIMARY`节点，可以执行`rs.slaveOk()`来执行查询。

但当使用`replicaSet`连接串来访问`mongo`服务时，连接却会失败。看看这个连接串，感觉不出任何问题。

```
mongo mongodb://127.0.0.1:27017,127.0.0.1:27018,127.0.0.1:27019/admin?replicaSet=rs0
```

看了报错信息，才明白：当执行连接的时候，`mongo`会拉取`replica set `的配置信息，而通过`host`去访问的时候失败了。很明显：`docker-compose`容器内可以将`server name`当作`host`来相互访问，但在容器外通过`server name`是访问不通的。

```
changing hosts to rs0/mongo1:27017,mongo2:27017,mongo3:27017 from rs0/127.0.0.1:27017,127.0.0.1:27018,127.0.0.1:27019
```

另外，你还可以在容器内部打开`/etc/hosts`文件，查看容器内映射的ip地址，容器外也是ping不通的。我们可以通过下面的指令进入容器查看：

```shell
docker exec -it <container-id> bash 
less /etc/hosts
```

解决的办法是，我们在本地主机上追加`host`。但这样的话，`rs0`其实只有一个节点，因为都映射到了`127.0.0.1:27017`这个容器上。

```host
# file: /etc/hosts
127.0.0.1 mongo1, mongo2, mongo3
```

基于这个原因，我们修改了容器内外暴露的端口。同时，修改各个服务`mongod`启动时的默认端口以及`replica set`的配置信息：

```yml
mongo1:
    container_name: mongo1
    image: mongo:4.0.4
    expose:
      - 37017
    ports:
      - "37017:37017"
    restart: always
    entrypoint: [ "mongod", "--port", "37017", "--bind_ip_all", "--replSet", "rs0" ]
  mongo2:
    container_name: mongo2
    image: mongo:4.0.4
    expose:
      - 37018
    ports:
      - "37018:37018"
    restart: always
    entrypoint: [ "mongod", "--port", "37018", "--bind_ip_all", "--replSet", "rs0" ]
  mongo3:
    container_name: mongo3
    image: mongo:4.0.4
    expose:
      - 37019
    ports:
      - "37019:37019"
    restart: always
    entrypoint: [ "mongod", "--port", "37019", "--bind_ip_all", "--replSet", "rs0" ]
```

```js
// file :replicaSet.js

rsconf = {
    _id: "rs0",
    members: [
        {_id: 0, host: "mongo1:37017"},
        {_id: 1, host: "mongo2:37018"},
        {_id: 2, host: "mongo3:37019"}
    ]
}

rs.initiate(rsconf);
rs.conf();
```

做了这些修改，我们就可以正常访问`mongo`服务了：

```shell
mongo mongodb://mongo1:37017,mongo2:37018,mongo3:37019/admin?replicaSet=rs0
```



## 启动服务

首先，我们看看镜像能不能顺利编译过去：

```
docker-compose -f docker-compose.yml build
```

其次，我们启动容器服务：

```
docker-compose -f docker-compose.yml up
```

最后，关闭容器服务。这个命令相当于依次执行`docker container stop`、`docker-compose down`，很方便。

```
docker-compose -f docker-compose.yml down
```



## 总结

执行上一篇的测试用例，然后中途关闭一个节点，来查看执行效果。

启动容器：

```
docker-compose -f docker-compose.yml down
```

查看容器的运行情况：

```
docker ps
```

关闭其中一个容器：

```
docker container stop <container-id>
```

服务短暂的输出`.no reachable servers`错误信息后，由恢复正常了！
