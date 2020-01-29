---
title: mitmproxy使用

date: 2018-07-06

tags: [tools,net]

author: 付辉

---



介绍一款非常好用的抓包工具，官网地址：[https://www.mitmproxy.org](https://www.mitmproxy.org)。实际上，在调试苹果`IAP`支付时，始终没有抓成功过，反而因为设置了代理，导致苹果`沙盒用户`无法成功支付。它名字的全拼是`Man-in-the-middle-proxy`，代表中间人攻击。


## 常用的快捷键

1. 在列表界面，按`回车`进入详情界面
2. 在详情界面，按`q`返回列表界面
3. 在详情界面，按`tab`键在`Request`,`Response`,`Detail`三个`tab`之间切换。按`j`，`k`可以滚动查看详情.
4. 在列表界面，按`G`跳到最新一个请求
5. 在列表界面，按`g`跳到第一个请求
6. 在列表界面，按`d`删除当前选中的请求，按`D`恢复刚才删除的请求
7. 在列表界面，按`z`清空请求列表


## 常用的过滤表达式

列表界面,按`f`进入过滤模式。详细的过滤表达式，可以查看：[`Filter expressions`](https://docs.mitmproxy.org/stable/concepts-filters/)。



1. `~h regex	Header`
2. `~u regex	URL`
3. `~m regex    Method`

## 原理

 1. [Subject Alternative Name](https://en.wikipedia.org/wiki/Subject_Alternative_Name)：is an extension to X.509 that allows various values to be associated with a security certificate using a subjectAltName field. These values are called Subject Alternative Names (SANs). Names include
 2. [Server Name Indication](https://en.wikipedia.org/wiki/Server_Name_Indication)： is an extension to the TLS computer networking protocol by which a client indicates which hostname it is attempting to connect to at the start of the handshaking process. This allows a server to present multiple certificates on the same IP address and TCP port number and hence allows multiple secure (HTTPS) websites (or any other service over TLS) to be served by the same IP address without requiring all those sites to use the same certificate. 

