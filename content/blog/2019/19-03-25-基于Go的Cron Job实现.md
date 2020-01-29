---
title: 基于Go的Cron Job实现

date: 2019-03-25

tags: [golang]

author: 付辉

---

>`随风要稳，逆风要浪`



## `timer`

> The Timer type represents a single event. When the Timer expires, the current time will be sent on C.

下面使用`timer`实现在固定时间点执行`task`任务。

处理思路：每次在执行`task`前，计算`当前时间`和`执行时间点`的差值，通过设置`timer`未来的触发时间来执行任务。在完成本次`task`之后，重置`timer`的触发时间，等待下一次执行。

```go
const IntervalPeriod time.Duration = 24 * time.Hour

// 核心函数：在h:m:s的时候执行task任务
func runningRoutine(hour, minute, second int, task func() error) {
	ticket := time.NewTimer(GetNextTickDuration(hour, minute, second))
	for {
		<-ticket.C
		if err := task(); err != nil {
		}
		ticket.Reset(GetNextTickDuration(hour, minute, second))
	}
}

// 获取Task执行的时间
func GetNextTickDuration(hour, minute, second int) time.Duration {
	nextTick := time.Date(time.Now().Year(), time.Now().Month(), time.Now().Day(),
		hour, minute, second, 0, time.Local)
	if !nextTick.After(time.Now()) {
		nextTick = nextTick.Add(IntervalPeriod)
	}

	return nextTick.Sub(time.Now())
}
```

## `ticker`

ticker只要定义完成，从此刻开始计时，不需要任何其他的操作，每隔固定时间都会触发。

```go
func simulateCronByInterval(interval time.Duration, task func()) {
	ticker := time.NewTicker(interval)
	defer func() {
		ticker.Stop()
	}()

	for {
		<-ticker.C:
			task()
	}
}
```

----



参考文章：

1. [Golang: Implementing a cron / executing tasks at a specific time](https://stackoverflow.com/questions/19549199/golang-implementing-a-cron-executing-tasks-at-a-specific-time)

