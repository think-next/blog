---
title: Nginx总结

date: 2018-03-10

tags : [nginx]

author: 付辉

---

## location 指令

工作中经常用到的一个指令，用来对某个路径的请求做特殊处理。比如同样的链接在`PC`和`Web`显示不同的页面。

### location修饰符

location block匹配request url中domain name 或者ip/por之后的请求部分，即请求资源的路径。

形式如下：
```
location optional_modifier location_match {

}
```

如下是`optional_modifier`的类型：

<table>
  <tr>
​    <th>optional_modifier</th>
​    <th>含义</th>
  </tr>
  <tr>
​    <td> = </td>
​    <td>请求的url必须严格匹配被location指定的路径，必须完全相同</td>
  </tr>
  <tr>
​    <td>none</td>
​    <td> 如果没有修饰符，将对url做前缀匹配</td>
​  </tr>  
  <tr>
​    <td>^~ </td>
​    <td>最佳的非正则表达式前缀匹配 </td>
  </tr>
  <tr>
​    <td>~ </td>
​    <td>大小写敏感的正则匹配 </td>
  </tr>
  <tr>
​    <td>~* </td>
​    <td>大小写不敏感的正则匹配 </td>
  </tr>
</table>



### location匹配规则

1. nginx会查找一个精确匹配。如果匹配到了 =  modifier，匹配会立即终止，该location就会被选择处理这个请求。
2. 如果没有精确匹配（= modifier），nginx继续进行前缀匹配，对于给定的url，选择最长的前缀匹配。然后依据下列规则，继续匹配。
3. 如果最长的前缀匹配有（^~ modifier），nginx会立即结束查询，选择该location。如果没有 ^~ modifier，该匹配会被暂时存起来，以便搜索可以继续。
4. 最长的匹配被存起来后，nginx会继续匹配正则表达式。nginx移动到 location list 的顶部，然后试着去匹配正则表达式，第一个被匹配的正则表达式会立即被选择处理请求，结束匹配。
5. 如果没有正则表达式被匹配，则之前存储的最长location被选择用来处理请求。

特别需要理解的：nginx正则匹配结果优先于前缀匹配。但是前缀匹配在先，同时允许通过 ^~ 和 = 来改变这种趋势。

前缀匹配一般选择最长，最精确的匹配，而正则匹配在第一个匹配发现时，匹配就会终止。也就是说，正则匹配跟配置文件中规则的定义位置有很大关系。
如果匹配上该location，请求会跳出匹配。

### 举个例子

当前想修改一下，针对某个请求`/fuhui/twenty/index.html`静态文件的根路径，即所以请求该路径的静态资源，统一到`/src/www/fuhui/twenty`目录下查找。

在`nginx`中做了如下配置。所以`nginx`按照流程，前缀匹配到`/fuhui/twenty`之后，判断它其实就是前缀匹配中最长的匹配。同时，它的修饰符为`^~`，`location`匹配完成。

假设②将修饰符修改为普通的前缀匹配（none），则①的`location`会匹配成功。
```
# 1
location ~* \.html$ {
    add_header Pragma "no-cache";
    try_files $uri /resource/html/$uri =404;
}

# 2
location ^~ /fuhui/twenty {
    root /src/www/fuhui/twenty;
} 
```

## error_page 返回状态码
语法： 
```
error_page code [code...] [=|=answer-code] url | @named_location
```

当对于某个请求返回错误码时，如果匹配上了error_page中设置的code,则重定向到新的url中，例如：
```
error_page 404 /404.html
error_page 502 503 /50x.html
```

注意，虽然重定向了url，但是返回的http错误码还是与原来的相同，用户可以通过=号来更改返回的错误码
```
    error_page 404 =200 /empty.gif
```

也可以不指定确切的返回错误码，而由重定向后实际处理的真实结果来决定，这是，只要把=后面的错误码去掉即可
```
    error_page 404 = /empty.gif
```

### 举个例子
禁用外网IP访问内网服务器，返回`403 forbidden`。
```
location / {
    # 允许内网ip访问
    allow 10.xx.xx.xx/24;
    
    # 禁止其他所有ip访问
    deny all;
}

error_page 403 @403error

location @403error {
    rewrite /403.html;
    
    # 重要
    allow all;
}
```

未完待续，敬请期待.....