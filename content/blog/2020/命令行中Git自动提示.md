---
title: "Oh My ZSH使用"
date: "2020-08-11"
lead: "命令行中Git自动提示"
comments: true # Enable Disqus comments for specific page
authorbox: true # Enable authorbox for specific page
pager: true # Enable pager navigation (prev/next) for specific page
mathjax: true # Enable MathJax for specific page
sidebar: "right" # Enable sidebar (on the right side) per page
widgets: # Enable sidebar widgets in given order per page
  - "recent"

---

访问 [oh-my-zsh](https://ohmyz.sh/#install) 的官网，直接进行安装，但安装过程出现了下面的错误提示：
```bash
neojos@localhost ~ % sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
curl: (7) Failed to connect to raw.github.com port 443: Connection refused
```

通过 dig 查看域名 raw.github.com 的DNS 解析结果，返回的是 0.0.0.0。整个域名的解析过程出了问题。因为网络的域名解析出了问题，所以，直接配置 hosts 文件。

通过 [https://www.ipaddress.com/](https://links.jianshu.com/go?to=https%3A%2F%2Fwww.ipaddress.com%2F) 查询域名对应的 IP 地址，在 /etcs/hosts 文件中添加如下记录：

```
199.232.68.133 raw.githubusercontent.com
199.232.68.133 raw.github.com
```

重新执行安装的 shell 命令，可以正常完成安装。



第二步，我们修改 .zshrc 文件。我们需要下载对应的插件，用于自动提示命令行输入。执行如下的的指令：

```bash
git clone git://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions

#编辑~/.zshrc，在plugins=(git)这一行中添加plugins=(git zsh-autosuggestions)
source ~/.zshrc
```



当我们再次在命令行输入 shell 时，便会出现自动提示了。