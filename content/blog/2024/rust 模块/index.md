---
title: rust 模块笔记
date: 2024-08-25
author: 付辉

---

### 模块 mod 的作用

- rust 通过模块来进行访问控制，功能类似 C++语言中的 class。可以控制模块成员的访问属性，公有属性或者私有属性
- 模块的依赖关系，它也包含父模块和子模块的关系。子模块可以访问父模块中的私有属性，但必须显示进行导入
	- 有两个关键字 self 和 super 可以用来表示这两种关系

下面是一个简单的demo，包含 main.rs 和 people.rs 两个文件，其中 people.rs 中实现了两个方法，然后，在 main.rs 中进行了调用。可以看出 mod 的声明效果，通过 mod 的声明来实现模块的查找并使用。

```
// people.rs:
pub struct Person {
    name: String,
    age: u8,
}

impl Person {
    pub fn new(name: String, age: u8) -> Self {
        Person { name, age }
    }

    pub fn greet(&self) {
        println!("Hello, my name is {} and I am {} years old.", self.name, self.age);
    }
}
```

```
// main.rs
mod people;

fn main() {
    let person = people::Person::new("Alice".to_string(), 30);
    person.greet();
}
```

### self 和 super

提供了相对路径的模块导入，结合模块声明和模块使用来最终确认使用哪个关键字：关注的点其实是声明和使用两个动作

- use mod super::utils; 表示模块导入
- mod utils; 表示模块声明

有模块声明，就有三方依赖的外部模块，这里需要使用另外的关键字：extern

### 文件路径和 mod 的关系

文件系统的文件和目录结构与模块具有绑定的对应关系，utils/mod.rs 就属于这种绑定关系的代表，它表示了 mod utils 的模块。

### workspace 

同一个项目下可以有多个子项目，主要是指文件夹下包含 Cargo.toml 的目录。主项目下可以包含多个这样的目录，然后在存储库的根目录下创建一个 Cargo.toml 来进行统一编辑管理

终于再来再来

## 构建 websocket 服务

参考文档：https://blog.logrocket.com/build-websocket-server-with-rust/
1. `uuid` crate will be used to create unique connection IDs
2. `futures` crate will be helpful when dealing with the asynchronous data streams of the WebSocket.