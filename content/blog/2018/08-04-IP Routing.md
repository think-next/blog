---
title: IP Routing

date: 2018-08-04

tags: [tcp/ip,net]

author: 付辉

---

假设你在跟小米公司对接服务，那你有没有好奇过：自家的服务器是如何找到小米公司的服务器的。为了安全，公司的服务器可都是在内网的，用户是无法直接访问到的。好好了解一下Ip Routing，它可以给你部分答案。

## 概述

当主机`IP(Network)`层收到一个`datagram`后，它首先会检查`datagram`的目标主机是不是自己。如果是，那么它会将`datagram`发送给其他协议处理。如果不是，它便检查自己是否被配置作为一个路由。如果是，它将按照规则将`datagram`继续传递。否则，默默的把`datagram`丢掉。

所有`routing`提供的`IP`地址，都假设下一个`hop`是离目标地址最近的。在`datagram`传递的过程中，我们会修改`link-layer`的地址为下一个`hop`的地址，而`Destination IP`一般是不做修改的。

## `Routing Table`

在命令行执行 `netstat -rn`，查看系统的`routing table`。
```
# 展示结果做了修改，非真实值

neojos@BJ ~ $ netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
140.168.0.0     10.3.206.240   255.255.0.0     UG        0 0          0 eth0
```

### 了解`Falgs`参数：

1. `U`  表示当前路由是在使用的
2. `G`  表示路由到一个`gateway`。如果没有设置该`flag`，则表示跟`Destination`是直接连接的。
3. `H`  表示路由到一个主机地址。如果没有设置该`flag`，则`Destination`是一个网络地址。
4. `D`  表示路由是通过`ICMP Redirect`设置的。一般来说，`Redirect`设置的`route`都是主机地址。

### 路由查询的顺序：

1. 查找匹配的主机地址
2. 查找匹配的网络地址
3. 查找`default`的路由。

## `Host unreachable`

当`route`没有找到`destination`时，`Destination Host Unreachable`的错误会返回给源主机。你可以通过`ping`路由表中配置错误的`destination host address`来查看。

## `ICMP Redirect Error`