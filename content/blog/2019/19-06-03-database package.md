---
title: database package

date: 2019-06-03

tags: [golang]

author: 付辉

---

## 清除无效连接

在database库下清除过期连接时，使用了如下的代码逻辑。其中freeConn是空闲连接池，d是连接可被重复使用的最长时间，nowFunc返回的是当前时间。最新生成的连接在freeConn的末尾，而清除的过程则是使用最新的、次新的连接依次替换最早过期的、次早过期的连接。

在for循环中直接使用len来获取总计数，在循环体内部将freeConn末尾的值替换首部的值，并将freeConn的len长度减去1。最后还做了`i—`操作，重复校验了一次。

```go
expiredSince := nowFunc().Add(-d)
var closing []*driverConn
for i := 0; i < len(db.freeConn); i++ {
	c := db.freeConn[i]
	if c.createdAt.Before(expiredSince) {
		closing = append(closing, c)
		last := len(db.freeConn) - 1
		db.freeConn[i] = db.freeConn[last]
		db.freeConn[last] = nil
		db.freeConn = db.freeConn[:last]
		i--
	}
}
```

### 参考点

slice中首部和尾部数据的交换过程，以及每次通过`i--`达到的重复校验的思路。

## 间隔执行

清除无效连接的工作是由一个goroutine在后台完成的，下面是截取的部分代码。for循环内部是处理连接的具体实现。每次清除操作完成后，通过Reset来重置Timer。

```go
func (db *DB) connectionCleaner(d time.Duration) {
	const minInterval = time.Second

	if d < minInterval {
		d = minInterval
	}
	t := time.NewTimer(d)

	for {
		select {
		case <-t.C:
		case <-db.cleanerCh: // maxLifetime was changed or db was closed.
		}

		if d < minInterval {
			d = minInterval
		}
		t.Reset(d)
	}
}
```

### 参考点

学习NewTimer函数的使用，它在声明后仅仅执行一次。通过Reset来重新使他生效。这样可以忽略操作执行的具体时间，每次都在上次操作完成后，间隔固定时间，再执行下一次操作。

还可以对比NewTicker做比较。

## 获取连接

从freeConn中获取一个缓存的连接，拿到连接之后并将它从freeConn中移除。同时，校验连接是否已经超过最大连接使用时间。

```go
if strategy == cachedOrNewConn && numFree > 0 {
	conn := db.freeConn[0]
	copy(db.freeConn, db.freeConn[1:])
	db.freeConn = db.freeConn[:numFree-1]
	conn.inUse = true
	db.mu.Unlock()
	if conn.expired(lifetime) {
		conn.Close()
		return nil, driver.ErrBadConn
	}
	return conn, nil
}
```

### 参考点

使用copy对slice的第一个元素进行移除。同时，通过重新赋值来修改slice的len属性。
