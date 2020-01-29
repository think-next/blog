---
title: 了解Laravel依赖注入

date: 2018-04-05

tags: [php,]

author: 付辉

---

## 随笔

突然想了解一下`Laravel`，然后发现：它没有我想象的那么简单，很多的调用都找不到入口。加载`view`的逻辑，看了很长时间，还是没有搞明白：一个值传递的参数，怎么好好的就变了呢？下面都是看别的的文章的总结，我还要继续完善，直到搞清楚这个`view`是怎么实现的。

看了两篇文章，介绍了如何使用[`xdebug`](https://xdebug.org/)断点调试`php`及测试性能。作为了解`Laravel`的必要工具，也介绍进来。

1. [`How to Install Xdebug with PHPStorm and Vagrant`](https://www.sitepoint.com/install-xdebug-phpstorm-vagrant/)
2. [`Debugging and Profiling PHP with Xdebug`](https://www.sitepoint.com/debugging-and-profiling-php-with-xdebug/)

## 概要

使用`use Illuminate\Container\Container;`作为参考的例子。

可以浏览原创：[Laravel Container (容器) 深入理解 (下)](https://segmentfault.com/a/1190000011560253#articleHeader4)。

摘抄`Laravel`

>The Laravel service container is a powerful tool for managing class dependencies and performing dependency injection.

通过`config/app.php`可以查看`Laravel`的`Service container`。`Service`下的`register`便是用来创建`binding`的。通过`php artisan make:provider CustomServiceProvider`创建自定义的`ServiceProvider`。

>There is no need to bind classes into the container if they do not depend on any interfaces. The container does not need to be instructed on how to build these objects, since it can automatically resolve these objects using reflection.

## `type hint`

对于`type hint`类型的注入。比如`MyContainer`构造函数注入：`public function __construct(AnotherClass $dependency)`，在构造函数中声明了依赖类。当我们直接使用`Container`去创建该对象时，`Container`会尝试为我们自动创建`AnotherClass`这个类。

比如我们执行`$container->make(MyContainer::class);`，框架自动帮我们去创建`AnotherClass`类。**但**也需要看`AnotherClass`类是否配合。如果`AnotherClass`的构造函数中指定了传递参数`__construct($a, $b)`，但在`make`函数中我们并没有传递任何参数，此时系统并不能帮我们自动生成。而是会报错：

`make`主要来创建该实例类，等同于代码中的`new`。

```
Illuminate\Contracts\Container\BindingResolutionException : 
Unresolvable dependency resolving [Parameter #0 [ <required> $a ]] in class Tests\Unit\AnotherClass

```

## `Binding Interfaces to Implementations`

> 代码开发中，上层模型不应该依赖底层，两者应该依赖抽象。抽象不应该依赖具体，具体却应该依赖抽象。

例子也请参照这篇文章：[`Dependency Injection`](https://www.sitepoint.com/dependency-injection-laravels-ioc/)。简要介绍：`FileSessionStorage`和`MySqlSessionStorage`实现了`SessionStorage`接口。之后在`SimpleAuth`构造函数中注入依赖`public function __construct(SessionStorage $session )`。

当我们调用`make`去实例化`SimpleAuth`对象时，因为仅通过接口，无法明确实例化一个实现该接口的类。系统报错：
```
Illuminate\Contracts\Container\BindingResolutionException : 
Target [Tests\Unit\SessionStorage] is not instantiable while building [Tests\Unit\SimpleAuth].
```

解决的办法是`Register a binding`。明确告诉系统，这个`interface`去具体实现那个类：`$container->bind( SessionStorage::class, MysqlSessionStorage::class);`。

结合这个例子，绑定之后意味着：通过这个`interface`，`make`再也无法创建`FileSessionStorage`类了。只能更新`binding`才能切换了。

## `Closure Binding`

方法：`bind($abstract, $concrete = null, $shared = false)`

方法主要是`Register a binding`，保存了`abstract`和`concrete`及`shared`的对应关系。

内部其实对`concrete`做了处理：`if (! $concrete instanceof Closure){`，最终还是会将该`concrete`转换为一个闭包函数，在框架初始化`abstract`时调用该闭包函数。

这样设计属于`lazily mode`，只有当对象对调用时，才会创建对象。具体可以查看[`Factories`](http://php-di.org/doc/php-definitions.html#factories)。闭包函数的唯一参数是：`Container $container`。当实例化对象时，`this`会被传入：`return $concrete($this, $this->getLastParameterOverride());`

## `Resolving Callbacks`

`Container`创建完对象之后，执行的回调函数。

方法：`resolving($abstract, Closure $callback = null)`。

`Container`将回调函数保存到`resolvingCallbacks`变量中：`$this->resolvingCallbacks[$abstract][] = $callback;`，可以创建多个`callback`回调。

当对象创建完成之后，执行`fireResolvingCallbacks($abstract, $object)`来调用函数。

## `Extending a Class`

用来对一个对象进行扩展，可以封装一个类然后返回一个不同的对象 (装饰模式)。代码中`$object = $extender($object, $this);`负责处理这个逻辑。

方法：`extend($abstract, Closure $closure)`。

当实例已经存在，直接调用回调函数处理。否则，将`Closure`存储到成员变量中：`$this->extenders[$abstract][] = $closure;`

当`resolve`创建对象成功之后，依次调用`extenders`中的回调进行处理。所以，回调定义的顺序就显得重要了。而且回调函数最后也必须返回一个正确的对象。

## `singleton`

`Container`使用`instances`来存储单例对象，且通过`isShared`方法来判断是否为单例对象

方法：`singleton($abstract, $concrete = null)`

跟`bind`方法完全相同，只是明确的将`shared`参数设置为`true`。之后，在`$this->bindings[$abstract] = compact('concrete', 'shared');`将`shared`标识保存在`binding`数组中。

当调用`make`创建对象之前，首先查看`isset($this->instances[$abstract])`是否存在。

方法：`instance($abstract, $instance)`

将已经存在的实例，设置为单例模式。其实就是将该实例保存到`instances`中：`$this->instances[$abstract] = $instance;`

## `Arbitrary Binding Names`

方法：`bind($abstract, $concrete = null, $shared = false)`

对于`abstract`可以指定任意的字符串，而不是类/接口名称。但这种情况下不能使用类型提示，并且只能用`make()` 来获取实例。

方法：`alias($abstract, $alias)`

给一个类型指定一个别名。该方法操作两个变量`aliases`，`abstractAliases`。具体如下：`$this->aliases[$alias] = $abstract; $this->abstractAliases[$abstract][] = $alias;`

可以看出：别名唯一对应一个类型，类型可以对应多个别名。

## `Contextual Binding`

参照：[传送门](https://segmentfault.com/a/1190000011560253#articleHeader19)


