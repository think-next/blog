---
title: shell操作文本实例

date: 2018-05-15

tags: [linux]

author: 付辉

---

从掌握`awk`的基本指令，到在工作中熟练使用，中间还有一段路要走！通过总结一些工作中需要的案例，来加深理解。

## 打印符合条件的前一行记录

这个案例很抽象，可能非常难遇到，除非自己给自己挖坑。

业务代码中处理每条数据，都会顺序输出两条日志。第一条表示要处理的数据内容，第二条表示处理的结果。现在想滤出来所有处理成功的记录。比如日志文件如下：
```
uid=1
HAPPY
uid=2
SAD
uid=3
SAD
```

处理的`AWK`脚本如下：
```
#! /bin/bash

# testPage表示日志文件
pieces=$(awk '/HAPPY/{line=NR-1;print line}' testPage | xargs) 
for piece in $pieces
do
    echo $(awk NR==$piece testPage)
done
```

脚本总结：

1. 首先通过`正则表达式`过滤，获取执行成功的数据行号。然后传递给`xargs`，转换为空格分隔的字符串。
2. 遍历每个行号。值得注意，`shell`中对空格分隔的字符串可以直接使用`for...in`
3. 通过`awk`条件判断，打印该行内容

## 求解两个文件的差集

### 使用`comm`实现

存在`A`和`B`两个系统，理论上`A`系统中的数据都应该存在于`B`系统中。但当核对数据时，发现两者数据不一致。如何有效的找出数据的差集。

具体到真实环境，通过`MySQL`，导出了满足条件的`A`、`B`系统数据的`id`，文件格式是`csv`。但当我执行如下列命令，获取仅仅在文件a中存在的记录时，发现数据完全不正确。

```shell
comm -2 -3 a.txt b.txt
```

调查发现，需要将两个文本先排好序，才能正常返回。
```
sort a.txt > a-sort.txt
sort b.txt > b-sort.txt
comm -2 -3 a-sort.txt b-sort.txt
```

### 使用`uniq`及`sort`实现

如下这种方式，仅仅可以找出不匹配的记录。无法区分数据是仅仅存在A系统，还是仅仅存在B系统。只能获取数据的交集和差集两部分。

原理很简单，将两个系统的文件合并到一个文件，然后排序。最终交集的数据，应该有2条记录。差集的记录，只有1条。

```
cat a.txt b.txt > merge.txt
sort merge.txt | uniq -c | sort | head -10
```



