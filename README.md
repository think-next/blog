# neojos blog
This repository will contain Hugo’s content and other source files.

## 配置submodules

当前项目下·public目录是作为submodules存在的，当使用包管理工具时，需要明确声明.gitmodules文件，内容如下：

```xml
[submodule "public"] 
  path = public 
  url = https://github.com/GitHubSi/githubsi.github.io.git
```

