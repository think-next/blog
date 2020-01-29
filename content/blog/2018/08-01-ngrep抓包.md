---
title: ngrep抓包

date: 2018-08-01

tags: [linux,tools,net]

author: 付辉

---

简单的工具其实挺有用的。警告：不许瞧不起工具，尤其是你还不会用的工具。

`ngrep`还是之前跟花椒直播的同事对接项目时，了解到的一个工具。它可以用来抓取服务器上通过网卡的所有请求。跟`tcpdump`差不多，但却更简单。`tcpdump`需要借助`Wireshark`才可以将请求完美展示出来，但这个就跟使用`grep`一样。

以前专门请教过一个同事如何使用`Wireshark`分析网络请求，自己也专门看了相关的`Wireshark`操作。但最终却发现，如果是抓客户端的请求(非分析`TCP`)，`Wireshark`使用起来并不方便。而如果分析的是服务端之间的请求，还需要借助`tcpdump`先来把请求记录下来，然后再到`Wireshark`中打开分析。

## `Example`

经常使用的模式
```
# 匹配特定host
ngrep -q host api.open.huajiao.com -d any -W byline

# 匹配特定host和端口
ngrep –q host api.open.huajiao.com and port 80  –W byline 

# 报文中包含"search"关键字
ngrep –q –W byline "search" host www.google.com and port 80 
```

## `Options`

详细还是通过`man`直接查看工具说明吧！这里列举一个：

    -d  By default  ngrep will select a default interface to listen on.
              Use this option to force ngrep to listen on interface dev.

## `结果示例`

以下是命令输出的结果，跟`curl`是不是很像：
```
interface: any
filter: ( host api.open.huajiao.com ) and (ip or ip6)

T **.***.***.***:80 -> **.***.***.***:56181 [AP]
HTTP/1.1 200 OK.
Server: nginx/1.2.9.
Date: Wed, 15 Feb 2017 09:18:07 GMT.
Content-Type: application/json.
Transfer-Encoding: chunked.
Connection: close.
Cache-Control: no-store.
.
48.
{"errno":35,"errmsg":"\u670d\u52a1\u5668\u88ab\u62d2\u7edd","consume":6}.
0.
.
```