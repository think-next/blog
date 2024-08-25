---
title: 数据统计
date: 2024-07-19
author: 付辉

---

了解`classification_report`之前，假装去构造一个应用场景，产出分类报告并给出解释。直接给出报告解释会比较干。

对数据进行分类，我们的数据就选择 30 条双色球数据，在其中放入 10 条中一等奖的数据，将这个数据集分成2类，一类是中奖的数据集，一类是不中奖的数据集

这个例子完全牵强，但也不需要过分纠结，重要的是熟悉流程。


![api key](api_key.png)

## python 环境

![python](pyhthon.png)

## venv

创建虚拟的 pyhon 运行环境

```python
python -m venv venv
source venv/bin/activate
cd venv
pip install xxx    // python -m pip install xxx 替换使用
```

关闭虚拟环境：
```python
deactivate
```

![[Pasted image 20240804220823.png]]