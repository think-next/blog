# neojos blog
This repository will contain Hugo’s content and other source files.

## 配置submodules

当前项目下·public目录是作为submodules存在的，当使用包管理工具时，需要明确声明.gitmodules文件，内容如下：

```xml
[submodule "public"] 
  path = public 
  url = https://github.com/GitHubSi/githubsi.github.io.git
```

## 自动提交

这个博客由2部分代码组成：

1. 源码。这个在`github`上有一个专门的代码库
2. `hugo`编译后的代码，这个直接在源码代码中嵌套了`submodules`。

所以每次有新的修改都需要提交两次，而且每次还需要输入用户名和密码，这真是痛苦无比的事情。最终还是提交了`simple-deploy.sh`脚本，来自动做这件事。