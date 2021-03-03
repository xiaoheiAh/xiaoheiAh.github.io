---
title: "Redis HA - 哨兵模式"
date: 2019-11-23T17:56:15+08:00
draft: false
tags: ["redis"]
categories: ["redis"]
description: "「Redis 学习笔记」| HA | 高可用 | 哨兵模式 | sentinel"
featured_image:
---

Redis 官方高可用(HA)方案之一: **哨兵模式**

<!--more-->

这篇文章已经介绍的很全面了:https://juejin.im/post/5b7d226a6fb9a01a1e01ff64 自己就总结一些问题:

## sentinel 如何保证集群高可用?

1. 时刻与监控的节点保持心跳(PING),订阅 `__sentinel__:hello` 频道实时更新配置并持久化到磁盘
2. 自动发现监听节点的其他 `sentinel` 保持通信
3. 节点不可达时询问其他节点确认是否不可达,是否需要执行故障转移(半数投票)
4. 故障转移后广播配置,帮助其他从节点切换到新的主节点,以 `epoch` 最大的配置为准

## sentinel 如何判定节点下线?

[主观下线/客观下线](#主观下线/客观下线)



## sentinel 的局限性?

`Redis Sentinel` 仅仅解决了 **高可用** 的问题，对于 **主节点** 单点写入和单节点无法扩容等问题，还需要引入 `Redis Cluster` **集群模式** 予以解决。



## 官方文档介绍

> https://redis.io/topics/sentinel
>
> 使用 `sentinel` 的原因: 做到无人工介入的自动容错 `redis` 集群.

`sentinel` 宏观概览:

* **监控 Monitoring:** 持续监控主从节点的运行状态
* **通知 Notification:** 节点异常时,通过暴露的 `API` 可以及时报警
* **自动故障转移 Automatic Failover:** 主节点宕机后,可以自动晋升从节点为新主节点,其他节点会重新连接到新主节点,应用也会被通知相应的节点变化
* **提供配置 Configuration Provider:** `sentinel` 维护着主从的节点信息,客户端会连接`sentinel` 获取主节点信息. 

`sentinel` **天生分布式,**多节点协同的好处在于:

* 多数节点都同意主节点不可用时才执行故障检测.有效避免错判.
* 多节点可以提升系统鲁棒性(`system robust`),避免单点故障

### 使用须知

1. 至少 3 个 `sentinel` 保证系统鲁棒性
2. 节点最好放在不同的主机或虚拟机,降低级联故障(一下全GG)
3. 由于 `redis` 采用的是异步复制,`sentinel` + `redis` 不能保证故障期间确认的写入(主从可能无法通信,确认复制进度).`sentinel` 可以在发布时控制一定时间内数据不丢失,但也不是万全之策.
4. 客户端需要支持 `sentinel` (常用 `Java` 客户端基本都支持)
5. 高可用并不是百分之百有效,即时你时时刻刻都在测试,产线环境也在跑,保不准凌晨就 GG,也没办法不是.
6. `Sentinel`,`Docker`，或者其他形式的网络地址交换或端口映射需要加倍小心：Docker执行端口重新映射，破坏`Sentinel`自动发现其他的哨兵进程和主节点的 `replicas` 列表。

### Sentinel 设置

`redis` 安装目录下有一个 `sentinel.conf` 模板配置可以参考.最小化配置如下:

```plain
sentinel monitor mymaster 127.0.0.1 6379 2
sentinel down-after-milliseconds mymaster 60000
sentinel failover-timeout mymaster 180000
sentinel parallel-syncs mymaster 1

sentinel monitor resque 192.168.1.3 6380 4
sentinel down-after-milliseconds resque 10000
sentinel failover-timeout resque 180000
sentinel parallel-syncs resque 5
```

不需要配置 `replicas` , `sentinel` 可以自动从主节点中获取 `INFO` 信息.同时该配置也会实时重写的: 新的 `sentinel` 节点加入或者故障转移 `replica` 晋升时.

#### `sentinel monitor <master-group-name> <ip> <port> <quorum>`

从命令就可以看出来一些名堂: 监控地址为 `ip:port,name` 为 `master-group-name` 的主节点.

**quorum:** 判断节点确实已经下线的支持票数(由 `Sentinel` 节点进行投票),票数超过一定范围后就可以让节点下线并作故障转移.但 `quorum` 只是针对于下线判断,执行故障转移需要在 `sentinel` 集群选举(投票)出一个 `leader` 来执行故障转移.

e.g. `quorum` = 2, `sentinel` 节点数 = 5

* 如果有两个 `sentinel` 节点认为主节点下线了,那么这两个节点中的一个会尝试开始执行故障转移.
* 如果有超过半数 `sentinel` 节点存在(当前情况下即活着 3 个 `sentinel` 节点),故障转移就会被授权真正开始执行.

**核心概念:** `sentinel` 节点半数不可达就不允许执行 **故障转移**.

#### `sentinel <option_name> <master_name> <option_value>`

`sentinel` 其它的配置基本都是这个格式.

* `down-after-milliseconds` 节点宕机超过该毫秒时间后 `sentinel` 节点才能认为其不可达.
* `parallel-syncs` 在发生failover主从切换时，这个选项指定了最多可以有多少个 `replica` 同时对新的`master` 进行同步，这个数字越小，完成主从故障转移所需的时间就越长，但是如果这个数字越大，就意味着越多的slave因为主从同步而不可用。可以通过将这个值设为1来保证每次只有一个 `replica` 处于不能处理命令请求的状态。

**所有配置都可以通过 `SENTINEL SET` 热更新.**

#### 添加/删除 sentinel 节点

**添加**: 启动一个新的 `sentinel` 即可.10s就可以获得其他 `sentinel` 节点以及主节点的 `replicas` 信息了.

**多节点添加**:建议 `one by one`,等到当前节点添加进集群后,再添加下一个.添加节点过程中可能会出故障.

**删除节点:** `sentinel` 节点不会丢失见过 `sentinel` 节点信息,即使这些节点已经挂了.所以需要在没有网络分区的情况下做以下几步:

1. 终止你想要关掉的 `sentinel` 节点进程
2. 发送一条命令 `SENTINEL RESET *` 给所有 `sentinel` 节点.如果只想对单一 `master` 处理,把 `*` 换成主节点名称.等一会儿~
3. 通过 `SENTINEL MASTER` 命令查看节点是否已删除

#### 主观下线/客观下线

`sentinel` 中有两种下线状态.

* **主观下线(Subjectively Down)** aka. SDOWN

  当前 `sentinel` 认为自己监控的节点下线了,即主观下线.`SDOWN` 判定的条件为: `sentinel` 节点向监控节点发送 `PING` 命令在设置的 `is-master-down-after-milliseconds` 毫秒后没有收到有效回复则判定为 `SDOWN`

* **客观下线(Objectively Down)** aka. ODOWN

  有 `quorum` 数量的 `sentinel` 节点认为监控的节点 `SDOWN`.当一个 `sentinel` 节点认为监控的节点 `SDOWN` 后,会向其它节点发送 `SENTINEL is-master-down-by-addr` 命令来判断其它节点对该节点的监控状态.如果回执为 **已下线** 的节点数+自身大于 `quorum` 数量,则判定为 **客观下线**

`PING` 命令的有效回复有什么?

* +PONG
* -LOADING error
* -MASTERDOWN error

其它回复都是无效的.需要注意的是: 只要收到有效回复就不会认为其 `SDOWN` 了.

`SDOWN` 并不能触发故障转移,只能判定节点不可用.要触发故障转移,**必须**达到 `ODOWN` 状态.

#### SDOWN -> ODWN?

`sentinel` 没有使用强一致性的算法来保证 `SDOWN` -> `ODOWN` 的转换,而是使用的[Gossip协议](https://zhuanlan.zhihu.com/p/41228196)来保证最终一致性.在给定的时间范围内,给定的 `sentinel` 节点收到了足够多(`quorum`)的其它 `sentinel` 节点的 `SDOWN` 确认,就会从 `SDOWN` 切换到 `ODOWN` 了.

真正执行故障转移时会有比较严格的授权,但是前提也得是 `ODOWN` 状态才行.`ODOWN` 只针对 `master` 节点,`replicas` 和 `sentinels` 只会有 `SDOWN` 状态.如果 `replica` 变为 `SDOWN` 了,在故障转移的时候就不会被晋升.

#### 自动发现 auto discovery

`sentinel` 节点之间会保持连接来互相检查是否可用,交换信息,但是并不需要在启动的时候配置一长串其他 `sentinel` 节点的地址. `sentinel` 会利用 `redis` 的 `Pub/Sub` 能力来发现监控了相同 `master/replicas` 的 `sentinel` 节点.`replicas` 自动发现是一样的原理.

##### 如何实现的?

向一个叫 `__sentinel__:hello` 的 `channel` 发送 hello 消息.

* 每个 `sentinel` 节点都会向每一个它监控的 `master` 和 `replica` 的叫做 `__sentinel__:hello` 的Pub/Sub channel 广播自己的 `ip`,`port`,`runid`.2s 一次.
* 每个订阅了 `master` 和 `replica` 的 `sentinel` 都会收到消息,并会去判断有新的 `sentinel` 节点就会被添加进来.
* 这个 `hello` 消息同样包含着最新的 `master` 全量配置,每个收到消息的 `sentinel` 会进行比对更新.
* 添加新的 `sentinel` 节点时会提前判断该节点信息是否已经存在.

#### sentinel 强制更新配置

**sentinel 是一个总会尝试将当前最新的配置强制更新到所有监控节点的系统**.

> 这可能也是一种 tradeoff 吧.比如 replica 如果连错 master 了,那 sentinel 就必须把它矫正过来,重连正确的master.

#### 副本选举

`sentinel` 可以执行故障转移时,需要选择一个合适的 `replica` 晋升.

##### 评估条件

* 与 `master` 的断连时间
* `replica` 优先级->可以设置
* 复制进度 `offset`
* Run ID

##### 判定需要跳过的节点

```bash
(down-after-milliseconds * 10) + milliseconds_since_master_is_in_SDOWN_state
```

如果一个 `replica` 的断连时间超过上面这个表达式,那就认为该节点不可靠,不考虑. `down-after-milliseconds` 是通过设置的,`milliseconds_since_master_is_in_SDOWN_state` 指在执行故障转移时 `master` 仍不可用的时间.

##### 选举过程

符合上述条件后才会对其按照条件进行排序.顺序如下:

* 首先根据 `replica-priority` 排序(`redis.conf` 进行设置),值越小越优先
* `priority` 相同时,比较 `offset`,值越大越优先(同步最完整)
* 如果 `priority`,`offset` 都相同,就会判断 `run ID` 的字典序.越小的 `run ID` 并不是说有什么优势,但是比起重排序随机选一个 `replica`,字典序选举方式更有确定性更有用(大白话).

建议所有节点都设置 `replica-priority`.如果  `replica-priority` 设置为 0, 表示永远不会被选为 `master` .但是在故障转移后 `sentinel` 会重置通过这种方式设置的配置,以便可以与新的 `master` 连接,唯一的区别就是该节点不会是主节点.

### 深入算法内部

#### Quorum

`quorum` 参数会被 `sentinel` 集群用来判断是否有这个数量的 `sentinel` 节点认为 `master` 已经 `SDOWN` 了,需不需要转为 `ODOWN` 触发故障转移 `failover`.

但是,触发故障转移后,至少需要有**半数**的 `sentinel` 节点(如果 `quorum` 值比半数还多,那其实需要有`quorum`个节点)授权给一个 `sentinel` 节点才能真正执行.小于半数节点不允许执行.

> e.g. 5 instances `quorum` = 2
>
> 当有2个节点认为 `master` 不可达时,就会触发 failover.但是需要有至少3个节点授权给这2个节点之一才能真正执行failover.
>
> 如果 `quorum` = 5,那就需要所有节点都认为 `master` 不可达,才能触发failover,并且所有节点都要授权.

#### 纪元 Configuration Epochs

为什么需要获取半数以上的授权执行 `failover`? 

当一个 `sentinel` 节点被授权后,会获得一个可以用于故障转移节点的唯一的纪元(`configuration epoch`)标志.这是一个在故障转移完成后针对新配置的版本号 number.因为是多数同意将指定的版本分配给指定授权的 `sentinel` ,所以不会有其他节点使用这个版本号.也就意味着每一次故障转移时生成的新配置都有唯一的版本号标识.

`sentinel` 集群有一条规则: 如果 sentinel A 投票给 sentinel B 去执行故障转移,A 会等待一段时间后对同一个主节点再次进行故障转移.这个时间可以通过 `sentinel.conf` 的 `failover-timeout` 进行配置.这就意味着不会有节点在同一时间对同一个主节点进行故障转移,被授权的节点回先执行,失败了后面会有其他的节点进行重试.

`sentinel` 保证 [liveness](https://en.wikipedia.org/wiki/Liveness) 特性(我的理解就是不会宕机一直存活):如果有多个节点可用,只会选择一个节点去执行故障转移.

`sentinel` 同样保证 [safety](https://en.wikipedia.org/wiki/Safety#System_safety_and_reliability_engineering) 特性:每一个节点都会尝试使用不同的 `configuration epoch` 对相同的节点进行故障转移.

#### 配置传递  Configuration propagation

故障转移完成后,`sentinel` 会广播新的配置给其他 `sentinel` 节点更新这个新的主节点信息.执行故障转移的主节点还需要对新的主节点执行 `SLAVE NO ONE`,稍后在 `INFO` 命令中就可以看到这个主节点了.

所有 `sentinel` 节点都会广播配置信息,通过 `__sentinel__:hello` channel 广播出去.配置信息都带有 `epoch` ,值越大越会被当做最新的配置.

#### 网络分区后的一致性问题

Redis + Sentinel 架构是**保证最终一致性**的系统,在发生网络分区恢复时,不可避免的会丢失数据.

如果把 redis 当做缓存来用,数据丢了也没事,可以再去库里查嘛.

如果把 redis 当做存储来用,那最好配上下面两个配置降低损失.

```bash
min-replicas-to-write 1
min-replicas-max-lag 10
```

#### Sentinel 状态持久化

Sentinel 状态持久化在 `sentinel.conf` 中,每次手挡新配置,或者创建配置,都会带着`configuration epoch` 一起持久化到硬盘,重启时就没有问题了.











































