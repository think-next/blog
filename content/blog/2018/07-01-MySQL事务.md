---
title: MySQL事务

date: 2018-07-01

tags: [MySQL]

author: 付辉

---

关于`MySQL事务`的诡异问题，至今没有调查出原因。但却也是一个契机，带我重新回忆之前的遇到的事务问题。

## 诡异的问题

系统中存在A和B两个表。B表中有两个关键字段：一个是唯一索引`transaction_id`，还有一个是标识处理状态的`status`。当`status=0`表示记录未被处理，`status=1`表示记录处理过了，不需要再处理了。

如果B中记录未处理，则在A表中插入一条权益记录，同时更新`status=1`，后续就不能再给用户加权益了。

代码做了如下处理：
```go
func sessPart() {

	//开启事务
	session := engine.NewSession()
	sess.Begin()
	defer session.Close()
	defer sess.Rollback()

	//插入价钱100分的权益交付记录
	exchange := models.Exchange{Money: 100, Uid: 1}
	_, err := sess.Insert(exchange)
	if err != nil {
		sess.Rollback()
		return
	}

	//更新status为1
	//并且使用乐观锁，防止因没有匹配到数据，直接返回成功
	testModel := Test{
		Status: 1,
	}
	affectRows, err := sess.Where("transaction_id = ? AND status = 0", 1).
		Cols("status").Update(&testModel)
	if err != nil || affectRows == 0 {
		sess.Rollback()
		return
	}

	sess.Commit()
}

//测试事务的并发情况
func BenchmarkLock(b *testing.B) {

	//控制并发，保证并发完成
	var wg sync.WaitGroup
	for i := 0; i < 500; i++ {

		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			sessPart()
		}(i)
	}

	wg.Wait()
}
```
**结论**：无论我怎么模拟并发，事务都很好的保证了：整个过程，只成功插入了一条记录。这倒是跟我预期一样。**但为什么我们线上环境，这样的代码能插入两条权益记录？**



## 事务隔离级别

`SQL`标准中定义了4种数据库事务的隔离级别。

1. `Read uncommited`表示未提交读。可能读取到其他会话中未提交事务修改的数据。也就是所谓的“脏读”。

2. `Read Commited`只能读取到已经提交的数据。但同一个事务执行同样的查询语句，读取的数据可能不一致。**原因是**：只会对记录加记录锁，而不会在记录之间加间隙锁，所以允许新的记录插入到被锁定记录的附近。当多次执行查询语句时，可能得到不同的结果。**解决了`Dirty Read`的问题**。

3. `Repeatable Read`在同一事务内的查询始终和事务开始时刻一致。在事务内，对数据读取或写入时会锁定这些数据行，但是这种方式存在幻读问题，因为只能锁定读取或写入的行，不能阻止另一个事务插入数据。**原因是**：多次读取同一范围的数据会返回第一次查询的快照，不会返回不同的数据行，靠自身的`MVCC`控制机制实现。**解决了`Non Repeatable Read`的问题**。

4. `Serializable`，与可重复读的唯一区别是，默认把普通的SELECT语句修改为`SELECT...LOCK IN SHARE MODE`，即查询语句返回的数据加上共享锁，阻碍其他事务修改真实数据。**解决了`Phantom Read`问题**。

## 查询数据库的隔离级别

```sql
-- 返回：READ-COMMITTED
SELECT @@tx_isolation;
```
正如查询所示，我们设置的是`READ-COMMITTED`。所以针对B表来说，如果并发两个事务，那第二个事务需要等待第一个事务释放锁之后才能执行`update`语句。此时第二个事务在回写时会发现`status != 0`，则回写失败，理应触发回滚。

