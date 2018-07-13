---
title: MySQL事务

date: 2018-07-01

categories: [2018-07]

tags: [事务]

author: 付辉

---

关于`MySQL事务`的诡异问题，至今没有调查出原因。但却也是一个契机，带我重新回忆之前的遇到的事务问题。

## 诡异的问题

系统中存在A和B两个表。B表中有两个关键字段：一个是唯一索引`transaction_id`，还有一个是标识处理状态的`status`。当`status=0`表示记录未被处理，`status=1`表示记录处理过了，不需要再处理了。

如果B中记录未处理，则在A表中插入一条权益记录，同时更新`status=1`，后续就不能再给用户加权益了。

代码做了如下处理：
```go
//简化的代码
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