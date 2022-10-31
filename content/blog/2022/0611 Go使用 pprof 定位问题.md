---
title: "Go使用Pprof定位问题"
date: "2022-06-11"
lead: "flat和cum的区别是什么"
comments: true # Enable Disqus comments for specific page
authorbox: true # Enable authorbox for specific page
pager: true # Enable pager navigation (prev/next) for specific page
mathjax: true # Enable MathJax for specific page
sidebar: "right" # Enable sidebar (on the right side) per page
widgets: # Enable sidebar widgets in given order per page
  - "recent"
---



两种使用 pprof 定位问题的形式：

1. 在 test 用例中使用 `runtime/pprof` 中提供的方法
2. 在 web 服务中引入 `"net/http/pprof"` 



定位问题的过程，经常会用到火焰图。但火焰图也只能算是一个扩展加分项，数据同样还是从`go tool pprof`中获取的。一般也只看cpu、和堆栈的内存分配情况。



但我依旧存在一个疑问，针对CPU的Profile文件，在执行top命令时，这些列头究竟是什么意思？换一句话描述我的问题， flat 和 cum 的区别是什么？ 

```
 flat  flat%   sum%        cum   cum%
```



查阅官方的解释文档，下面是自认为官网比较关键性的解释：

> The first two columns show the number of samples in which the function was running (as opposed to waiting for a called function to return), as a raw count and as a percentage of total samples
>
> The third column shows the running total during the listing
>
> The fourth and fifth columns show the number of samples in which the function appeared (either running or waiting for a called function to return). To sort by the fourth and fifth columns, use the -cum (for cumulative) flag:



字面上的意思很好理解： flat 表示样本中当前函数占用的CPU时间，cum表示当前函数以及当前函数调用其他函数的时间。但到底是不是这个意思呢，我也不是很清楚。



思考了很久之后，我突然意识到另一个问题：在火焰图上，标识函数占比的数据，依靠了是 flat 还是 cum 呢？我顿悟式的有了一个假设：火焰图上使用的肯定是 cum，而 cum 数据是用于反应函数调用栈信息的。



果不其然，确实如此。





