---
title: "RabbitMQ-入门及高可用集群部署"
date: 2019-09-04T14:42:13+08:00
draft: false
markup: "mmark"
categories: ["消息队列"]
description: "「RabbitMQ 学习笔记」| docker 部署"
tags : ["rabbitmq"]
---

<!--more-->

> rabbitmq version: 3.7.15

## 常用操作

1. `sbin/rabbitmq-server` 启动
2. `sbin/rabbitmq-server -detached` 后台启动
3. `sbin/rabbitmqctl shutdown/stop` 关闭/停止server
4. `sbin/rabbitmqctl status` 检查server状态 
5. `sbin/rabbitmq-plugins enable rabbitmq_management` 开启控制台

## 端口

1. server启动后默认监听`5672`
2. 控制台默认监听`15672`

## 构建集群

### 构建集群的方式

1. 在`config`文件中声明节点信息
2. 使用`DNS`发现
3. 使用`AWS`实例发现(**通过插件**)
4. 使用`kubernetes`发现(**通过插件**)
5. 使用`consul`发现(**通过插件**)
6. 使用`etcd`发现(**通过插件**)
7. 手动执行`rabbitmqctl`

### 节点名称

- 节点名称是节点的身份识别证明.两部分组成: `prefix` & `hostname`.例如 `rabbit@node1.messaging.svc.local`的`prefix`是 **rabbit** ,`hostname`是 **node1.messaging.svc.local**.

- 集群中名称必须 **唯一**. 如果使用同一个`hostname` 那么`prefix`要保持不一致
- 集群中,节点通过节点名称互相进行识别和通信.所以`hostname`必须能解析.`CLI Tools`也要使用节点名称.

### 单机集群构建

单机运行多节点需要保证:

- 不同节点名称 `RABBITMQ_NODENAME`
- 不同存储路径 `RABBITMQ_DIST_PORT`
- 不同日志路径 `RABBITMQ_LOG_BASE`
- 不同端口,包括插件使用的 `RABBITMQ_NODE_PORT`

#### rabbitmqctl 构建集群

```bash
RABBITMQ_NODE_PORT=5672 RABBITMQ_NODENAME=rabbit rabbitmq-server -detached
RABBITMQ_NODE_PORT=5673 RABBITMQ_NODENAME=hare rabbitmq-server -detached
# 重置正在运行的节点
rabbitmqctl -n hare stop_app
# 加入集群
rabbitmqctl -n hare join_cluster rabbit@`hostname -s`
rabbitmqctl -n hare start_app
```

每个节点若配置有其他的插件.那么每个节点插件监听的端口不能冲突,例如添加控制台

```bash
# 首先开启控制台插件
./rabbitmq-plugins enable  rabbitmq_management
RABBITMQ_NODE_PORT=5672 RABBITMQ_SERVER_START_ARGS="-rabbitmq_management listener [{port,15672}]" RABBITMQ_NODENAME=rabbit ./rabbitmq-server -detached
RABBITMQ_NODE_PORT=5673 RABBITMQ_SERVER_START_ARGS="-rabbitmq_management listener [{port,15673}]" RABBITMQ_NODENAME=hare ./rabbitmq-server -detached

# 加入rabbit节点生成集群
rabbitmqctl -n hare stop_app
# 加入集群
rabbitmqctl -n hare join_cluster rabbit@`hostname -s`
rabbitmqctl -n hare start_app

```

以上就建了带控制台的两个节点.

#### 遇到的问题

1. 添加节点进集群时,报错

   ```bash
   ./rabbitmqctl -n rabbit2 join_cluster rabbit@`hostname -s`
   
   Clustering node rabbit2@localhost with rabbit@localhost
   Error:
   {:inconsistent_cluster, 'Node rabbit@localhost thinks it\'s clustered 	with node rabbit2@localhost, but rabbit2@localhost disagrees'}
   ```

   集群残留的`cluster`信息导致认证失败.删除`${RABBIT_MQ_HOME}/var/lib/rabbitmq/mnesia`文件夹.再`reset`节点

2. 建集群报错

   ```bash
   Clustering node rabbit2@localhost with rabbit@localhost
   Error:
   {:corrupt_or_missing_cluster_files, {:error, :enoent}, {:error, :enoent}}
   ```

   同上

3. 启动第三个节点时爆端口占用,该端口是第一个节点的控制台端口`15672`.**没有解决**

   ```bash
   2019-09-05 15:35:42.749 [error] <0.555.0> Failed to start Ranch listener rabbit_web_dispatch_sup_15672 in ranch_tcp:listen([{cacerts,'...'},{key,'...'},{cert,'...'},{port,15672}]) for reason eaddrinuse (address already in use)
   ```

## 使用案例

#### Topic Exchange

`topic`类型的`exchange` ,`routing key` 是按一定规则来的,通过`.`连接,类似于正则.有两种符号:

* `*` 代表一个单词
* `#` 代表0或多个单词

如果 单单只有`#`号, 那么`topic exchange`就像`fanout exchange`,如果没有使用`*`和`#`,那就是`direct exchange`了.



## 参考

1. [docker hub rabbit mq 镜像](https://hub.docker.com/_/rabbitmq/)