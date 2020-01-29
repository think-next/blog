---
title: RequireJS初识 

date: 2018-01-29 20:10:33 

tags: [js]

author: 付辉

---

开发上想找一个时间选择控件，无意中就找到了[layDate 日期与时间组件](http://www.layui.com/laydate/)。

直接下载源码，在文件中引入.js和.css文件，但是调用的时候产生异常了。很好奇！作为一名服务端开发，我一直都是这样搞的，百试不爽。今天却翻车了！！查看错误发现是require这个方法报的错，主要的原因是：laydate未定义。

为什么要引入requirejs，这个东西到底该怎么用呢？从后端的角度看：它其实就是扮演PHP中的 spl_autoload_register的角色。当执行JS的时候，自动去调用执行脚本所需的js。

所以对代码做如下修改,主要用来配置加载js的路径。

注：如果是本地资源，千万不要写成如下代码所示的：域名+路径的形式（见注释掉的baseUrl）。当正式服和测试服域名不相同时，就比较麻烦。我就是因为我们测试服的域名是woniu-test，正式服我的域名是woniu，结果require的加载请求一直请求的是woniu的域名，找了半天才发现这个问题。

```js
<script>
requirejs.config({
    //baseUrl: 'http://woniu/resource'
    baseUrl: '/resource/',
    //paths: {
    //    laydate: 'js/laydate'
    //},
    //shim:{
    //    'laydate': {
    //        deps: ['js/laydate'],
    //        exports: 'laydate'
    //    }
    //}
});
</script>
```
调用的时候直接如下调用，就ok了！！
```
<script>
    require(['js/laydate'], function (_){
        // called once the DOM is ready
        laydate.render({
            elem: '#input-end-time', //指定元素
            type: 'datetime'
        });
        laydate.render({
            elem: '#input-start-time', //指定元素
            type: 'datetime'
        });
    });
</script>
```