---
title: rust option的处理
date: 2024-11-09
author: 付辉

---

对于 option 类型处理，属于 rust 入门级功法，实操 coding 的感受会比较深刻。写这部分内容的时候，是通过 hugo-edit 的途径来编辑的，hugo 提供了创建免费个人博客的途径，但这个途径本身并方便，我其实希望通过 hugo-edit 来改变这一点。

最近书中读到曾国藩的语录：“一句不通，不看下句；今日不通，明日再读；今年不精，明年再读；此所谓耐也。困时切莫间断，熬过此关，便可少进。再进再困，再熬再奋，自有享通精进之日”。大家都应该学习这样的耐性。这段时间对 hugo-edit 项目差点放弃，其实就是缺少耐力。

## is_some
判断 option 变量是否有值，可以通过 match 语法来匹配获取，其实也可以用来判断是否有值，但这种方式不直观，rust 提供了 is_none 和 is_some 两个方法来识别 None 和 Some 两种情况，这样做的好处就是特别直观，但它们应该被用于哪些使用场景呢？

```rust
fn get_value(x: Option<i32>) -> i32 {
    match x {
        Some(v) => v,
        None => 0, // 如果是None，返回默认值0
    }
}
```

is_some 可以用来判断全局缓存，如果变量中有值的话，直接使用变量的值；如果变量没有值的话，重新给变量赋值。但如果就是要获取 option 的值，这样的判断就显得不必须了。

## if let
当我们只需要处理 Option 的一种情况时，if let 就显得格外有用，主要是因为它要比 match 表达式更简洁，而且它还不需要调用 unwarp 函数。我对于 unwarp 函数的印象不是特别好，它的错误返回需要和外部函数返回相匹配，算起来也是挺多限制的。

if let 模式匹配的代码应该怎么写，下面以 Some 为匹配获取其中的值，当然也可以通过 None 来匹配 Option 没有任何值的情况。不过，它和 is_none 在使用上有些相似的地方。

```rust
fn main() {
    let maybe_number: Option<i32> = Some(42);

    // 如果有值，就打印出来
    if let Some(number) = maybe_number {
        println!("The number is: {}", number);
    }

    // 同时处理多种情况
    let mut stack = Vec::new();
    while let Some(top) = stack.pop() {
        println!("Popped: {}", top);
    }
}
```

### 引用匹配模式
ref 关键字表示创建了一个对值的引用，而不是拷贝。如果没有关键字 ref，程序会尝试获取值的所有权，也就是所有权会发生转移，在一些场景下是存在问题的。

```rust
struct ProjectConfig {
    config: Option<String>,
}

fn main() {
    let project_conf = ProjectConfig { config: Some("hello".to_string()) };

    if let Some(ref config_str) = project_conf.config {
        println!("Config: {}", config_str);
    } else {
        println!("No config found");
    }
}
```