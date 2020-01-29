---
title: Mark-sweep GC

date: 2019-02-15

tags: [translate]

author: 付辉

---

> `把事做成的才是赢家，在口头上压倒对手，真的没有那么重要！`

## Whirlwind introduce

当对象不再被引用时，对象不会立即被垃圾回收。也不存在任何子系统来专门记录使用的内存情况。

当系统没有内存空间时，触发`GC`处理。它首先会枚举所有的`Root`对象，然后递归的遍历根对象的引用关系。给遍历到的对象设置一个特殊标记，表明该对象是可达的，空间不能被回收。

当标记结束后，`GC`进入清洗阶段，任何在内存中没有被这次垃圾回收标记的对象都会被系统回收。

## The algorithm

程序主要包含3个阶段：列举所有`Root`对象、标记起始于`Root`的对象引用、清除无效的对象。
```c
void GC()
{
    HaltAllProcessing();
    ObjectCollection roots = GetRoots();
    for(int i = 0; i < roots.Count(); ++i)
        Mark(roots[i]);
    Sweep();
}
```

## `Root Enumeration`

`Root Enumeration`会列举系统所有对象引用。运行系统需要为`GC`提供一种获取`Root`对象列表的机制。比如，在`.NET`中`JIT`维护了当前活跃的`root`对象，提供了获取根对象列表的`API`。

一个函数接受一个指针类型的参数，当方法返回时，`jitter`会识别出该参数不会再被使用，而将其从`root`中移除。

##  `Mark`

每个对象在创建时创建额外的空间，用于去`mark`这个对象，这个过程也是递归的

```c
void Mark(Object* pObj)
{
    if (!Marked(pObj)) // Marked returns the marked flag from object header
    {
        MarkBit(pObj); // Marks the flag in obj header

        // Get list of references that the current object has
        // and recursively mark them as well


        ObjectCollection children = pObj->GetChildren();
        for(int i = 0; i < children.Count(); ++i)
        {

            Mark(children[i]); // recursively call mark
        }	
    }
}
```

递归的结束条件是：

1. 任何一个对象都不再有孩子节点
2. 如果一个对象已经标记过了，要避免出现循环引用的情况

## `sweep`

`sweep`会遍历整个内存空间，释放没有被标记的内存。同时，它会清除标记的`bit`位，以便下次`GC`的正常标记。

```
void Sweep()
{
    Object *pHeap = pHeapStart;
    while(pHeap < pHeapEnd)
    {
        if (!Marked(pHeap))
            Free(pHeap); // put it to the free object list
        else
            UnMarkBit(pHeap);


        pHeap = GetNext(pHeap);
    }
}
```

## 总结

`Mark-sweep`天然适合清除循环引用的情况，然而它每次的循环遍历回收操作，会导致整个系统短暂的暂停，影响系统的正常交互。



参考文章：

1. [`Mark and Sweep Garbage Collection`](https://blogs.msdn.microsoft.com/abhinaba/2009/01/30/back-to-basics-mark-and-sweep-garbage-collection/)