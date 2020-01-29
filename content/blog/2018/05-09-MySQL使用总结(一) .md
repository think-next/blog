---
title: MySQL使用总结(一) 

date: 2018-05-09

tags: [MySQL,]

author: 付辉

---

## 查询的执行时间

第一次遇到查询时候报超时。很好奇，别的工具是如何修改查询的操时时间。

```
set max_statement_time = 0;
```

By using `max_statement_time`, it is possible to limit the execution time of individual queries.

1. The MySQL version of `max_statement_time` is defined in millseconds, not seconds.
2. MySQL's implementation can only kill SELECTs.

## `left join`

这个语句执行起来特别的费劲，但需求是：找出A表中存在，但B表中不存在的记录。

### `on`条件

一直以为`on`是在执行表关联时的判断逻辑，即两个表的记录要不要关联，全靠`on`。直到遇到`left join`。发现它完全没有理会`on`提供的左表过滤条件，它返回了左表的全部记录，需要将条件放到`where`中才生效。

举个例子
```sql
-- table_a.id > 2018 无效
select * from table_a 
left join table_b on table_a.id = table_b.a_id and table_a.id > 2018

-- 正确的方式
select * from table_a 
left join table_b on table_a.id = table_b.a_id 
where table_a.id > 2018
```

### 执行效率

还拿上面的方式来举例，它的执行非常慢。换一种思路，就会很快。

我们先获取两个数据集的交集，然后跟这个交集做`left join`。这种啰嗦的方式，居然会让查询的速度变快。

```
select * from table_a 
left join(
    select table_a.id from table_a 
    inner join table_b 
    on table_a.id = table_b.a_id 
) as table_out
on table_a.id = table_out.id 
where table_out.id > 2018
```

## 时间格式

MySQL提供了两个函数来转换`unix时间戳`和日期
```sql
-- 把 unix 时间戳转换为日期
from_unixtime()

-- 把日期转换为 unix 时间戳
unix_timestamp()
```