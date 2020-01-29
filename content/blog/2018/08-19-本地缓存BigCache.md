---
title: 本地缓存BigCache

date: 2018-08-19

tags: [golang]

author: 付辉

---


`BigCache`的作者做了详细的阐述，尽在这里：[`Writing a very fast cache service with millions of entries in Go`](https://allegro.tech/2016/03/writing-fast-cache-service-in-go.html)。不得不说，作者的表述非常完美，给它点赞。`GitHub`地址在：[github.com/allegro/bigcache](https://github.com/allegro/bigcache)。`Usage`非常简单。

## `Omitting GC`

当`map`中存储过百万的`object`时，`Go`语言自身的`GC`甚至会影响不相关的请求，即使是对一个空对象做`Marsh`操作，响应时间也可能在`1s`以上。所以，如何避免`Go`默认对`map`做的`Garbage Collector`至关重要。

1. `GC`回收`heap`中对象，所以我们不把对象创建在`heap`中就可以避过垃圾回收。查阅[`offheap`](https://godoc.org/github.com/glycerine/offheap)。
2. 使用[`freecache`](https://github.com/coocood/freecache).
3. 在`map`结构的`key`和`value`中不存储`pointer`，这样便可以将`map`创建在堆上，同时忽略`GC`的影响。这来源于`Go`的[优化](https://github.com/golang/go/issues/9477).


## `Concurrency`

为了避免加锁成为系统的瓶颈，`BigTable`采用了`Shared`的方式来解决，确实也有点`Redis`单线程的感觉。将一块大的数据划分成多块小的数据，为小数据块加锁，确实很好的缓解了加锁的瓶颈。这体现出了`拆分`的思想，突然想到了曾经被面试的问题：“请将2G的数据进行排序”。

我比较好奇它的`Hash`方法，客户端的`key`转换为实际存储的`hashedKey`的过程。请看通过`hashedKey`获取`shard`的部分，作者没有使用`%`取余来实现，而是使用了`&`与运算来替代，确实很注重细节啊！

说到与运算:`0&0=0;   0&1=0;    1&0=0;     1&1=1;`，所以，最终拆分个数完全取决与二进制中1的数量。如果`shardMask`等于3，那就可以拆分成4份，如果等于4，那结果就是2份，以此类推。

```
//通过客户端的key获取实际存储的key
// Sum64 gets the string and returns its uint64 hash value.
func (f fnv64a) Sum64(key string) uint64 {
	var hash uint64 = offset64
	for i := 0; i < len(key); i++ {
		hash ^= uint64(key[i])
		hash *= prime64
	}

	return hash
}


//通过实际存储的key获取shard块，使用与运算。
func (c *BigCache) getShard(hashedKey uint64) (shard *cacheShard) {
	return c.shards[hashedKey&c.shardMask]
}
```

## `Entry`中存储的数据

这也是我特别好奇的地方。因为作者只简单介绍了它是模拟`queue`实现的，而且在`map`的结构中，它存储的仅仅是`offset`。那么，它是如何通过一个`offset`来获取到完整的数据信息的？

如代码所示，每个`entry`由5部分组成，分别是时间戳(8`byte`)、`key`的`hash`值(8`byte`)、`key`的长度(2`byte`)、`key`的值本身以及`value`的值本身。这里通过`小端字节序`来存储，所以后续的反编译也应该指定这种模式。从`PutUint64`、`PutUint16`也可以对应到字节的大小。

```
func wrapEntry(timestamp uint64, hash uint64, key string, entry []byte, buffer *[]byte) []byte {
	keyLength := len(key)
	blobLength := len(entry) + headersSizeInBytes + keyLength

	if blobLength > len(*buffer) {
		*buffer = make([]byte, blobLength)
	}
	blob := *buffer

	binary.LittleEndian.PutUint64(blob, timestamp)
	binary.LittleEndian.PutUint64(blob[timestampSizeInBytes:], hash)
	binary.LittleEndian.PutUint16(blob[timestampSizeInBytes+hashSizeInBytes:], uint16(keyLength))
	copy(blob[headersSizeInBytes:], key)
	copy(blob[headersSizeInBytes+keyLength:], entry)

	return blob[:blobLength]
}
```

## `queue`存储

`queue`中每个元素都由2部分组成，前4个`byte`是数据的长度，后面是数据的值本身。其中`PutUint32`变需要4`byte`。所以`queue`中每个元素最下的长度应该是4，而它的值部分只能是0了。

```
func (q *BytesQueue) push(data []byte, len int) {
	binary.LittleEndian.PutUint32(q.headerBuffer, uint32(len))
	q.copy(q.headerBuffer, headerEntrySize)

	q.copy(data, len)

	if q.tail > q.head {
		q.rightMargin = q.tail
	}

	q.count++
}
```

关于`rightMargin`，用于标识队列中最后一个元素的位置，是一个绝对位置。所以，当队列需要扩容时，会`copy`该坐标之前的所有元素，如下面的示例代码。对于最正常的情况，该值跟`tail`相等。
```
copy(q.array, oldArray[:q.rightMargin])
```

关于`head`和`tail`是一个相对的坐标，而且跟严格意义上队列的两个属性不一致。在`queue`中存储的元素有`timestamp`的部分，而`head`所指向的元素不一定是最早插入队列的元素，同理,`tail`指向的元素也不是最晚插入队列的元素。它们会因为循环而相互变动，只要的作用便是：推断是否可以合理的插入新的元素。
```go
if q.tail < q.head {
	emptyBlobLen := q.head - q.tail - headerEntrySize
	q.push(make([]byte, emptyBlobLen), emptyBlobLen)
	q.head = leftMarginIndex
	//absoulate position to right margin
	q.tail = q.rightMargin
}
```

关于`leftMarginIndex`声明成一个常量，而且`head`默认从1开始。为什么要这样处理，注释给出的解释：
```
// Bytes before left margin are not used. Zero index means element does not exist in queue,
//useful while reading slice from index
```

关于申请新的空间，引入了`minimumEmptyBlobSize`，它占用36个`byte`。它其实占用了一个比实际需要大的多的空间。
```
minimumEmptyBlobSize = 32 + headerEntrySize
```
当`tail`和`head`间的空隙，不足以容纳当前要插入的元素的时候，期间需要插入一个空的元素，具体到下面的代码：
```
emptyBlobLen := q.head - q.tail - headerEntrySize
q.push(make([]byte, emptyBlobLen), emptyBlobLen)
```
这个赋值的意义在这行代码才体现出来，当申请空间的时候，需要一个默认的值来标识：是否可以申请空间了。那么`availableSpaceBeforeHead`是可能产生负数的。
```
func (q *BytesQueue) availableSpaceBeforeHead() int {
	if q.tail >= q.head {
		//leftMarginIndex mean
		return q.head - leftMarginIndex - minimumEmptyBlobSize
	}
	return q.head - q.tail - minimumEmptyBlobSize
}
```