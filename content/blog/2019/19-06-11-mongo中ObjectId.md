---
title: mongo中ObjectId

date: 2019-06-03

tags: [mongo]

author: 付辉

---

ObjectId在mongo中是自动生成的_id字段，充当数据表的主键ID。按照_id排序基本上等于按照记录的创建时间排序，但还是必须注意：_id并不是严格单调递增的，前4个byte的也只是精确到了秒级，同一秒内的_id并不能保证有序。

> ObjectIds are small, likely unique, faster to generate, and ordered. ObjectId values consist of 12 bytes, where the first four bytes are a timestamp that reflect the objectId's creation. Specifically
>- a 4-byte value representing the seconds since the Unix epoch
>- a 5-byte random value
>- a 3 byte counter, starting with a random value

## 排序

使用[github.com/globalsign/mgo](github.com/globalsign/mgo)的翻页逻辑：

```go
func (detail *CounterDetailMapper) GetDetailsByDesc(ctx context.IContext,
	objectId string, size int, startPoint string, data *[]models.CounterDetail) (err error) {

	if len(startPoint) == 0 {
		err = detail.Collection(ctx).Find(bson.M{"object_id": objectId}).Sort("-_id").Limit(size).All(data)
	} else {
		err = detail.Collection(ctx).Find(bson.M{"object_id": objectId, "_id": bson.M{"$lt": bson.ObjectIdHex(startPoint)}}).
			Sort("-_id").Limit(size).All(data)
	}

	if err != nil && err == mgo.ErrNotFound {
		return nil
	}
	return err
}
```

## 通过ObjectId获取时间戳

在命令行中输入如下命令，获取ObjectId中的时间戳:
```
> a = db.badge_progress.findOne({_id:ObjectId("5cff293017a6b9330facc88d")})

> a

> a["_id"]

> a["_id"].getTimestamp()
```
