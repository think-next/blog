---
title: rust 异步
date: 2024-11-11
author: 付辉

---

```
future cannot be sent between threads safely  
within `impl futures_util::Future<Output = ()>`, the trait `std::marker::Send` is not implemented for `std::sync::MutexGuard<'_, ConfigManager>`, which is required by `impl futures_util::Future<Output = ()>: std::marker::Send`
```

分析编译的报错信息，threads future not safely 很难理解，因为代码操作的对象是下面这样的。rust 把代码开发成这个样子也很值的称赞！我从其它途径获得问题的分析：无法在异步环境中使用同步阻塞操作。

通过 std::sync::Mutex 的 lock 方法获取锁会阻塞正在执行的线程，直到锁变得可用。在此期间，执行该任务的线程不能做任何其他工作，即使可能有其他非阻塞的工作可以进行。这与异步编程的目标相悖，因为它降低了应用的吞吐量和响应性，特别是在高并发环境下。

```rust
lazy_static! {
    static ref CONFIG_MANAGER: Arc<Mutex<ConfigManager>> =
        Arc::new(Mutex::new(ConfigManager::new("conf/hugo.toml".to_string())));
}
```

为了在异步环境中有效地使用锁定机制，我们可以考虑使用 tokio::sync::Mutex 这个库来替换 std 库，这个锁在尝试获取锁时不会阻塞线程。相反，如果锁当前不可用，它们会将当前任务挂起，并在锁变为可用时自动恢复任务。