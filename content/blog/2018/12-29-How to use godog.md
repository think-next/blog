---
title: How to use godog

date: 2018-12-29

tags: [translate,golang]

author: 付辉

---

首先访问`Git`的地址：[Godog](https://github.com/DATA-DOG/godog)，它也是用来做`Go Test`一样的事情，只是换了一种形式。引入了一个概念：[`BDD`](https://semaphoreci.com/community/tutorials/behavior-driven-development)。通俗的讲，就是虚拟现实场景，完成一个业务的测试。

## `Godog`了解
首先介绍`Godog`是用来干什么的，我也是根据版本库提供的`README`来解释的，建议大家自己去看看。首先，我们要定义一个场景：`feature`。这里我们创建一个文件夹`feature`，专门用来存储这类文件。然后创建一个文件：`godogs.feature`。文件内容如下：

```
# file: $GOPATH/src/godogs/features/godogs.feature
Feature: 购买红酒
    这里是一堆对这个Feature的描述
    描述的继续...

    Scenario: 买一瓶红酒
    Given Neojos Has 5 coins
    When I buy Red wine
    Then should be 1 remaining
```

在控制台执行`godog`时，控制台会输出默认建议的代码。输出如下：
```go
You can implement step definitions for undefined steps with these snippets:

func neojosHasCoins(arg1 int) error {
	return godog.ErrPending
}

func iBuyRedWine() error {
	return godog.ErrPending
}

func shouldBeRemaining(arg1 int) error {
	return godog.ErrPending
}

func FeatureContext(s *godog.Suite) {
	s.Step(`^Neojos Has (\d+) coins$`, neojosHasCoins)
	s.Step(`^I buy Red wine$`, iBuyRedWine)
	s.Step(`^should be (\d+) remaining$`, shouldBeRemaining)
}
```

可以看出，`godog`库根据我们的描述生成了对应的代码，我们只需要去完善具体的实现。可以看出，这里对出现的数字，使用了正则匹配。

关于`godog`提供的`hook`，下面还有这些：

```
BeforeScenario: runs before a scenario is tested,
BeforeStep: runs before each step,
AfterStep: runs after each step, and
BeforeSuite: runs before a suite of scenarios is run.
```
但这些其实并不是很必须，因为官方提供的`test`也实现了这样的功能，`testing.Main`就被用来这样搞。

## `BDD`了解

你可能之前听过这个概念，但简写了之后，你就不一定了认识了。全拼：`Behaviour Driven Development`。

基于行为驱动的开发，我理解就是基于业务流程的开发。它基于一个描述文件，将流程之间的调用关系通熟易懂的阐述给非技术人员。

比如在做测试的时候，我们可以这样模拟业务流程：

1. 请求A接口
2. 获取返回值
    1. 如果结果是M，执行X流程
    2. 如果结果是N，执行Y流程

下面是比较正规的描述：

> `Behaviour Driven Development (BDD) is an approach to ensure software development meets business goals. It’s accomplished by using a set of processes and tools that aid collaboration between technical and non-technical teams. At its heart is clear communication between business and technical teams, ensuring all development projects are focused on delivering what the organization needs while meeting requirements of users.`

## `BDD`延伸

强烈建议大家看一下参考文章[2]，虽然它没有介绍啥新的内容，但是它够系统，够专业。虽然我们平常可能也是这么做的，但是肯定不知道它属于什么方法论。

如下是设计模式中[瀑布开发模式](https://baike.baidu.com/item/%E7%80%91%E5%B8%83%E5%BC%80%E5%8F%91%E6%A8%A1%E5%BC%8F)。跟我们工作类似，这也是一般正常情况下的开发模式。

![image](https://i.loli.net/2018/12/28/5c26247537226.png)

但现实可能不是这样，这样的流程存在诸多可逆的情况。现实是这样的：

1. 开发一边在`Coding`，测试一边在`Testing`。测试不停地在反馈，开发不停地在修改、调整代码。但这样效率其实很低，有效的做法是**开发的同时及时完善测试用例**，开发人员在开发的同时，对开发的代码进行自测。这样的做法叫`test-first programing`。
2. 测试或开发的过程中，突然发现项目评估时系统设计方案有问题，设计方案需要做调整。但这样效率其实更低，任何代码不能开发到一半的时候才发现当前的设计方案行不通。所以在设计之前，技术上要做好测试，验证这样的设计在技术上是行得通的，然后在具体着手开发。这样的做法叫` test-driven development (TDD)`
3. 开发过程中，突然发现：原先的需求无法实现。或者产品觉得原先的需求很鸡肋，别的需求更重要。这样在代码上也需要做针对性的调整。这样的做法叫：`behavior-driven development`

综上所诉，才有了现在的**持续迭代，小步快跑**原则。

## `feature`

你有没有好奇`feature`的文件格式为什么是那个样子，而且`vim`会默认对`Given`、`When`这样的关键字高亮？这里需要了解一下`gherkin language`。大家可以移步到[3]。

这个语法设计的目的主要是：

1. 项目的文档介绍。省略掉逻辑实现的细节，用通熟的话来解释代码的流程
2. 自动化测试需要


### `Step`

`Step`是指`Given`、`When`、`Then`、`And`、`But`这种，虽然程序在处理的时候，并不会对这些关键字做区分，但在写`feature`文件的时候，我们需要做明确区分，方便我们合理的描述流程。

结合文章开头的例子，可能觉得例子太过于简单了。但实际上这个`gherkin`语法支持的功能也是很丰富的。包括它的`scenario outline`、`background`等。

## `behat`

读到这里，还剩下最后一点点。就是在命令行执行`godog`时，那些默认生成的建议代码。这里就需要联想到这个工具：`behat`。它基于[`behavior driven development(BDD)`](https://en.wikipedia.org/wiki/Behavior-driven_development)这个理念，用可读的故事来描述应用的行为。用它就可以将`feature`自动生成测试代码。

----
参考文章：

1. [`How to Use Godog for Behavior-driven Development in Go`](https://semaphoreci.com/community/tutorials/how-to-use-godog-for-behavior-driven-development-in-go)
2. [`Behavior-driven Development`](https://semaphoreci.com/community/tutorials/behavior-driven-development)
3. [`writing features - gherkin language`](http://docs.behat.org/en/v2.5/guides/1.gherkin.html)
4. [`http://docs.behat.org/en/v2.5/quick_intro.html`](http://docs.behat.org/en/v2.5/quick_intro.html)