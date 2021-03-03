---
title: "RabbitMQ-消息分发机制"
date: 2019-09-21T18:42:13+08:00
draft: false
categories: ["消息队列"]
description: "「RabbitMQ 学习笔记」| 理解rabbit消息的发送规则"
tags : ["rabbitmq"]
---

rabbitmq有多种使用模式,在这里记录下不同模式的消息路由规则

<!--more-->

## 预备知识

>  总结的不错的文章: https://blog.csdn.net/qq_27529917/article/details/79289564

#### Binding

`Exchange` 与 队列 之间的绑定为 `Binding`.绑定时可以设置 `binding key`, 发消息时会有一个 `routing key`, 当 `routing key` 与 `binding key` 相同时, 这条消息才能发送到队列中去.

#### Exchange Type

`Exchange` 有不同的类型, 每种类型的功能也是不一致的

1. **Fanout**

   把所有发送到该 `Exchange` 的消息转发到所有绑定到他的队列中

2. **Direct/默认(empty string)**

   根据 `routing_key` 来决定发送到具体的队列去

3. **Topic**

   `binding key` 可以带有匹配规则.

4. **Headers**

   不依赖 `binding key` 和 `routing key`, 只根据消息中的 `headers` 属性来匹配


## 模式列表

> 参考: https://www.rabbitmq.com/getstarted.html

### 直连

![](https://www.rabbitmq.com/img/tutorials/python-one-overall.png)

上图展示了 `Producer` 与 `Consumer` 通过 `Queue` 直连,  实际上在 `rabbitmq` 中是不能直连的,必须通过 `Exchange` 指定 `routingKey` 才可以. 这里我们可以使用一个默认的 `Exchange` (空字符串) 来绕过限制.

### 工作队列

![](https://www.rabbitmq.com/img/tutorials/python-two.png)

**直连** 属于一对一的模式,**工作队列** 则属于一对多, 通常用于分发耗时任务给多个`Consumer`.可以提升响应效率.消息的分发策略是 `轮询分发` .

### 发布/订阅

![https://www.rabbitmq.com/img/tutorials/python-three-overall.png](https://www.rabbitmq.com/img/tutorials/python-three-overall.png)

发布订阅模型是 `RabbitMQ` 的核心模式. 我们大多数也是使用它来写业务.之前的 **直连/工作队列** 模式, 我们并没有用到 `Exchange` ,都是使用默认的空`exchange`.但是在 **发布订阅** 模式中, `Producer` 只会把消息发到 `Exchange` 中,不会关注是否会发送到队列, 由 `Exchange` 来决定. 

**发布/订阅** 中的 `Exchange` 类型为 `Fanout`, 所有发到 `Exchange` 上的消息都会再发到绑定在这个`Exchange` 上的所有队列中.

### 路由模式

![](https://www.rabbitmq.com/img/tutorials/python-four.png)

**路由模式** 采用 `direct` 类型的 `Exchange` 利用 `binding key` 来约束发送的队列.



### Topic

![](https://www.rabbitmq.com/img/tutorials/python-five.png)

**Topic模式** 利用模式匹配,以及 `.`的格式来按规则过滤. `*` 代表只有一个词, `#`代表 0 或 多个.

