---
title: Deafult Decimal

date: 2018-12-01

tags: [MySQL]

author: 付辉

---

*<u>版本 0.00</u>*

> 我说：`version dependent` 表示我们的思考时，应该依赖具体的版本。举个例子，你把2015年看到的一些`redis`机制拿到现在跟别人谈论，很容易闹出笑话。在3年的时间里，它可能已经做了无数的优化。所以，思考要与时俱进。

## 引言

### 在涉及到支付业务的时候，数据库里的钱怎么存：

1. 存储单位是元。在业务处理的时候就会涉及到浮点数，很多商家喜欢将价钱定义为`0.99`而不是`1`元。这在使用过程中非常忌讳**是否相等**的比较。浮点数的比较经常喜欢用`|floatA - floatB| > 0.00001`来，很多第三方库也提供了比较方法。
2. 存储单位时分。为了避免浮点类型比较时的不确定性，决定使用整形来替代。一般来说没有问题，可如果是要严格缺心眼打折，比如给一个售价`4.99`的打`5折`，那么最后就会存在`5里`的情况。一般都喜欢向上取整，应收用户`2.495`，实收用户`2.50`.

### 那么在`MySQL`的`Column`中该如何存储呢？

1. 如果是分的话，肯定时当整形来存储的。但如果时浮点的，大家都会选择`decimal`，因为该类型不会丢失精度。
2. 存储为字符串。浮点数保留指定位数的字符串。在`Go`中我也尝试过，`fmt.Sprintf("%.2f", 3.091)`还是靠谱的。

这篇文章当然不是来分析这两种存储方式的，也不是来分析该存储什么数据类型的。而仅仅时想阐述一个之前不了解的知识点（知识点太少，写点别的来凑）。

## `deault value`

在`MySQL`建表的过程中，一般都会指定`DEFAULT VALUE`。在执行`INSERT`时，如果不指定该字段，`MySQL`会默认使用该默认值来替代。下面是创建的一个`decimal`类型字段，在`Go`中使用[`xorm`](https://github.com/go-xorm/xorm) 来表示，可以看出，`xorm`使用字符串类型来接收`decimal`类型的值。

```go
type table_test struct {
    PayPrice  string  `xorm:"not null default 0.00 comment('支付价钱') DECIMAL(10,2)"`
}
```

最后发现：在测试环境下，向数据库插入记录时，不指定`PayPrice`没有任何问题。但到了正式服数据表插入便失败了。报错信息如下：

```
{
    "Number": 1366,
    "Message": "Incorrect decimal value: '' for column 'pay_price' at row 1"
}
```

## `STRICT_TRANS_TABLES`

查询`sql_mode`如下：

```
show variables like 'sql_mode'
```

下面的内容截取至:[`Strict SQL Mode`](https://dev.mysql.com/doc/refman/8.0/en/sql-mode.html#sql-mode-strict):

> `Strict mode controls how MySQL handles invalid or missing values in data-change statements such as INSERT or UPDATE. A value can be invalid for several reasons. For example, it might have the wrong data type for the column, or it might be out of range. `

最终定位：**空字符串在该模式下转换decimal会失败，测试和线上数据库环境不一致**