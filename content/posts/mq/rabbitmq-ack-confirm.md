---
title: "RabbitMQ-消息确认机制"
date: 2019-10-23T11:22:13+08:00
draft: false
tags: ["rabbitmq"]
categories: ["消息队列"]
description: "「RabbitMQ 学习笔记」 | ACK 机制 "
featured_image: https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191023173920.png
---

RabbitMQ在保证生产端与消费端的数据安全上,提供了消息确认的机制来保证. 消费端到 `broker` 端的确认常叫做`ack机制`,  `broker` 到生产端常叫做`confirm`.

<!--more-->

## 消费端确认机制

#### Delivery Tag

`Delivery Tag` 是 `RabbitMQ` 来确认消息如何发送的标志. `Consumer` 在注册到 `RabbitMQ` 上后, `RabbitMQ` 通过 `basic.deliver` 方法向消费者推送消息, 这个方法中就带着可以在 `Channel`中唯一识别消息的 `delivery tag` . `Delivery Tag` 是`channel` 隔离的.

`tag`是一个大于零的增长的整型, 客户端在确认消息时将其当做参数传回来就可以保证是同一条消息的确认了.

`tag`是`channel`隔离的, 所以必须在接受消息的`channel`上确认消息收到,否则会抛 `unknown delivery tag`的异常.

**最大值:** `delivery tag` 是 64 位的`long`,最大值是 `9223372036854775807`. `tag`是`channel`隔离的,理论上来说是不会超过这个值的.

#### 确认机制

消息确认有两种模式: 自动/手动.

自动模式会在消息一经发出就自动确认.这是在**吞吐量**和 **可靠投递**之间的权衡.如果在发送的过程中, TCP断掉了或是其他的问题,那消息就会丢掉了,这个问题需要考虑.还需要考虑的一个问题是: `Consumer` 消费速率如果不能跟上`broker`的发送速率, 会导致`Consumer`过载(消息堆积,内存耗尽),而在手动模式中可以通过`prefetch`来控制消费端的速率.有些客户端会提供TCP的背压,不能处理时,就丢弃了.

手动模式需要`Consumer`端在收到消息后调用:

1. `basic.ack` : 消息处理好了,可以丢掉了
2. `basic.nack` : 可以批量`reject`, 如果`Consumer`设置了`requeue`,消息还会重新回到`broker`的队列中
3. `basic.reject` : 消息没有处理但是也需要删除

#### Channel Prefetch

由于消息的发送和接收是独立的且完全**异步**,消息的手动确认也是完全异步的.所以这里有一个未确认消息的滑动窗口.在消费端我们经常需要控制接收消息的数量,防止出现消息缓存`buffer`越界的问题.此时我们就可以通过`basic.qos`来设置`prefetch count`, 该值定义了一个`Channel`中能存放的消息条数上限,超过这个值,`RabbitMQ`在收到至少一条`ack`之前都不能再往`Channel`上发送消息了.

这里需要注意前面说的**滑动窗口**: 意味着当`Channel`满的时候,不会再往`Channel`上发消息,但是当你`ack`了一条,就会往`Channel`上发一条,`ack`了N条,就会发N条到`Channel`上.

`basic.get`设置`prefetch`是无效的,请使用`basic.consume`

#### 吞吐量影响因素: Ack机制 & Prefetch

确认机制的选择和`Prefetch`的值决定了消费端的吞吐量.一般来讲,增大`Prefetch`值以及 **自动确认** 会提升推送消息的速率,但也会增加待处理消息的堆积,消费端内存压力也会上升.

如果`Prefetch`无界,`Consumer`在消费大量消息时没有`ack`会导致消费端连接的那个节点内存压力上升.所以找到一个完美的`Prefetch`值还是很重要的. 一般 100-300 左右吞吐量还不错,且消费端压力不大. 设置为 1 时,就很保守了,这种情况下吞吐量就很低,延迟较高.

## 发布端确认机制

网络有很多种失败的方式,并且需要花时间检测.所以客户端并不能保证消息可以正常的发送到`broker`,正常的被处理.有可能丢了也有可能有延迟.

根据`AMQP-0-9-1`, 只有通过 **事务** 的方式来保证.将`Channel`设置为事务型的,每条消息都以事务形式推送提交.但是,事务是很重,会降低吞吐量,所以`RabbitMQ`就换了种方式来实现: 通过模仿已有的`Consumer`端的确认机制.

启用`Confirm`,客户端调用`confirm.select`即可.`Broker`会返回`confirm.select-ok`,取决于是否有`no-wait`设置. `Channel`如果设置了`confirm.select`,说明处于`confirm`模式,此时是不能设置为事务型`Channel`,两者不可互通.

`Broker`的应答机制同`Consumer`一致,通过`basic.ack`即可,也可批量`ack`.

#### 发布端的NACK

在某些情况下,`broker`无法再接收消息,就会向发布端回执`basic.nack`,意味着消息会被丢弃,发布端需要重新发布这些消息.当`Channel`置为`Confirm`模式后,后面收到的消息都将会`confirm`或者`nack` **一次**. 需要注意的几点:

1. **不能保证消息何时confirm.**
2. **消息也不会同时confirm和nack**
3. **只有在Erlang进程内部报错时才会有nack**

#### Broker何时确认发布的消息?

**无法路由的消息:** 当确认消息不会被路由时, `broker`会立即发出`confirm`. 如果消息设置了强制(`mandatory`)发送,`basic.return`会在`basic.ack`之前回执. `nack`逻辑一致.

**可路由的消息:** 所有`queue`接受了消息时返回`basic.ack` ,如果队列是持久化的,意味着持久化完成后才发出.对`镜像队列(Mirrored Queues)`,意味着所有镜像都收到后发出.

#### 持久化消息的ack延迟

`RabbitMQ`的持久化通常是批量的,需要间隔几百毫秒来减少 `fsync(2)`的调用次数或者等待 `queue` 是空闲状态的时候,这意味着,每一次`basic.ack`的延迟可能达到几百毫秒.为了提高吞吐量最好是将持久化做成异步的,或者使用批量`publish`,这个需要参考客户端的api实现.

#### 确认消息的顺序

大多数情况下, `RabbitMQ` 会根据消息发送的顺序依次回执(要求消息发送在同一个`channel`上).但确认回执都是异步的,并且可以确认一条,或一组消息.确切的`confirm`发送时间取决于: 消息是否需要持久化,消息的路由方式.意味着不同的消息的确认时间是不同的.也就意味着返回确认的顺序并不一定相同.应用方不能将其作为一个依据.

## 参考

1. https://www.rabbitmq.com/confirms.html#acknowledgement-modes