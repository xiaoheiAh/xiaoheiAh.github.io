---
title: "Redis HA - Cluster"
date: 2019-11-24T11:48:17+08:00
draft: false
tags: ["redis"]
categories: ["redis"]
description: "「Redis 学习笔记」| HA | 高可用 | 原生 cluster 模式"
markup: mmark
---

Redis 官方高可用(HA)方案之一: **Cluster**.可以解决 `sentinel` 模式单点写入的问题.

<!--more-->

## 参考

1.  https://juejin.im/post/5b8fc5536fb9a05d2d01fb11
2. http://www.redis.cn/topics/cluster-spec.html
3. https://redis.io/topics/cluster-spec

### 玩玩集群

https://redis.io/topics/cluster-tutorial

如果使用源码构建的,`utils` 目录下有一个脚本可以创建集群试玩.

<img src="https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191128201309.png" alt="create-cluster" style="zoom:50%;" />

## Redis Cluster 实现原理

### 一致性Hash算法

> **一致哈希** 是一种特殊的[哈希](https://zh.wikipedia.org/wiki/哈希)算法。在使用一致哈希算法后，哈希表槽位数（大小）的改变平均只需要对 $$K/n$$ 个关键字重新映射，其中$$K$$是关键字的数量，$$n$$是槽位数量。然而在传统的[哈希表](https://zh.wikipedia.org/wiki/哈希表)中，添加或删除一个槽位的几乎需要对所有关键字进行重新映射。
>
> -- [来自自由的百科全书](https://zh.wikipedia.org/wiki/一致哈希)

一致性 Hash 算法在很多领域都有实践,分布式缓存 Redis, 负载均衡 Nginx,一些 RPC 框架.一句话解释这个算法就是将请求均匀的分配给各个节点的算法.在 Redis 中就是对 key 的离散化,将其存到不同的节点上,在 Nginx 中就是讲请求离散化,均匀地达到不同的机器上,相同的请求始终可以打到同一台上.毕竟取模以后值又不会变,总是会到相同的一台嘛.

**一致性哈希** 可以很好的解决 **稳定性问题**，可以将所有的 **存储节点** 排列在 **收尾相接** 的 `Hash` 环上，每个 `key` 在计算 `Hash` 后会 **顺时针** 找到 **临接** 的 **存储节点** 存放。而当有节点 **加入** 或 **退出** 时，仅影响该节点在 `Hash` 环上 **顺时针相邻** 的 **后续节点**。



#### 普通模式

![normal-consistent-hash](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191128173619.png)

- **优点**

**加入** 和 **删除** 节点只影响 **哈希环** 中 **顺时针方向** 的 **相邻的节点**，对其他节点无影响。

- **缺点**

**加减节点** 会造成 **哈希环** 中部分数据 **无法命中**。当使用 **少量节点** 时，**节点变化** 将大范围影响 **哈希环** 中 **数据映射**，不适合 **少量数据节点** 的分布式方案。**普通** 的 **一致性哈希分区** 在增减节点时需要 **增加一倍** 或 **减去一半** 节点才能保证 **数据** 和 **负载的均衡**。

#### 虚拟槽

**虚拟槽分区** 巧妙地使用了 **哈希空间**，使用 **分散度良好** 的 **哈希函数** 把所有数据 **映射** 到一个 **固定范围** 的 **整数集合** 中，整数定义为 **槽**（`slot`）。这个范围一般 **远远大于** 节点数，比如 `Redis Cluster` 槽范围是 `0 ~ 16383`。**槽** 是集群内 **数据管理** 和 **迁移** 的 **基本单位**。采用 **大范围槽** 的主要目的是为了方便 **数据拆分** 和 **集群扩展**。每个节点会负责 **一定数量的槽**，如图所示：

![vslot-consistent-hash](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191128173930.png)

#### 为什么是 16384 个槽?

redis github 上有个对应的 [issue](https://github.com/antirez/redis/issues/2576), antirez 给了对应的回答.回答如下:

![why-redis-cluster-use-16384-slots](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191128175820.png)

总结下来就是避免节点之间交换消息时消息包过大.每个消息包都会通过 bitmap 存储当前节点的 slots 分配信息,slots = 16384 时占用 16384/8/1024 = 2KB. 65K slots就太大了,而且官方建议最好不要超过 1000 个节点,16k slots也就足够分配了.**够用就行**.

##### 为什么要提到 65K?

![why-mentioned-65k](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191128180222.png)

Redis 实现的 CRC16 算法是 16 位的,最大值就是 65535,以这个值来计算 bitmap 就是 8K 左右.

中文参考:https://www.cnblogs.com/rjzheng/p/11430592.html

## [官方集群文档](https://redis.io/topics/cluster-spec) 

**Redis Cluster Bus:**  节点的 TCP 通信及二进制协议的总称.所有节点通过 `cluster bus` 进行连接.还可以在集群中 传递 `Pub/Sub` 消息,处理手动的故障转移请求(用户执行).

**Gossip:** 通过 `Gossip` 协议传递集群消息保证集群每个节点最终都能获得所有节点的完整信息.

客户端不需要在意请求到哪个节点,随机请求一个后,如果没有查到对应的key,会通过返回重定向的结果 `-MOVED`,`-ASK` 来重定向到真正含有请求key数据的节点上.

#### 可用性 Availability

出现网络分区时, cluster 在少数节点侧分区是不可用的.在多数节点的分区侧(假设至少有半数的节点且存在每个不可用的主节点的 `slave` ),集群会在 `NODE_TIMEOUT` + 选举及故障转移所需一定时间 后恢复.

### Redis Cluster 核心组件

#### 键的分布式模型 Keys distribution model

键空间分割为 `16384` 个 slot, 也就是集群可以最多有 `16384` 个节点.(官方建议上线 1000 节点为佳)

每个 `master` 节点维护一段 slot.每一个主节点可以有多个 **slave** 来应对网络分区或者故障转移时的问题,以及分担读的压力.

核心算法: 将key进行hash取模映射到一个 slot 上. $$ HASH\_SLOT = CRC16(key)\ mod\ 16384 $$

**CRC16** 在测试中针对不同的key能很好的离散化.效果显著.

#### 集群拓补

`Redis Cluster` 的节点连接是网状的,假设有 N 个节点,那么每个节点都会与 N-1 个节点建立 TCP 连接, 且每个节点需要接受 N-1 个外来的 TCP 连接.所有连接都是 `keep alive`.如果等待足够长时间没有得到对方的 PING 回复,就会尝试重连.由于连接呈网状的原因,节点使用的是 `Gossip` 协议来传递消息,更新节点信息,可以避免节点之间同时交换巨量的消息,防止消息的指数型增长.

### 重定向&重新分片

#### MOVED Redirection

客户端可以向任意一个节点发送查询请求,包括 `slave` 节点.节点会对查询请求进行分析,如果该 `key` 就在当前节点,就直接查出来返回,如果不在,节点会去寻找该 `key` 对应的 slot 所属的节点是哪一个,然后返回给客户端一个 `MOVED` error.

```bash
GET x
-MOVED 3999 127.0.0.1:6381
```

该 error 包括了 `key` 所在的 slot,以及对应节点的 ip:port.客户端就可以重新对真正持有该 `key` 的节点发起查询请求.如果在发起请求前经过了很长的时间导致集群产生了重新配置(`reconfiguration`),客户端再发起请求后可能仍然没有拿到值,还是会收到一个 `MOVED` 响应,如此循环下去.

#### Cluster live reconfiguration

`Redis` 集群是允许运行时增删节点的.增删节点的影响就是对 hash slot 的调整.增加一个节点就需要把现有的节点匀出来一部分给新节点,删除一个节点就要把该节点的 slot 合并给其他节点.

核心的逻辑其实就是对 hash slots 的移动.从一个特殊的角度来看,移动 slot 就是移动一组 key,所以集群在 `resharding` 时真正做的其实是对 key 的移动.移动一个 hash slot 就是对该 slot 下的所有 keys 移动到另一个 slot 下.

##### Cluster Slot 相关命令

- [CLUSTER ADDSLOTS](https://redis.io/commands/cluster-addslots) slot1 [slot2] ... [slotN]
- [CLUSTER DELSLOTS](https://redis.io/commands/cluster-delslots) slot1 [slot2] ... [slotN]
- [CLUSTER SETSLOT](https://redis.io/commands/cluster-setslot) slot NODE node
- [CLUSTER SETSLOT](https://redis.io/commands/cluster-setslot) slot MIGRATING node
- [CLUSTER SETSLOT](https://redis.io/commands/cluster-setslot) slot IMPORTING node

`ADDSLOTS`, `DELSLOTS` 用于给节点分配/删除指定的 slots.分配后会通过 `Gossip` 广播该信息.`ADDSLOTS` 通常用在集群新建时为每一个 master 节点分配一部分 slot. `DELSLOTS` 主要用于手动设置集群配置或者用于 debug 时的操作.**通常很少用**.

`SETSLOT <slot> NODE` 使用该命令就是给一个节点分配指定的 slot.

否则就是需要设置 **MIGRATING** 和 **IMPORTING** 的命令了.这两个特殊的状态是为了将一个 slot 从一个节点迁移到另一个时使用的.

* 设置为 **MIGRATING** 时,节点会接受所有关于该 slot 的查询,但仅当 key 存在时,否则会返回一个 **-ASK** 的重定向转发到需要迁移到的目标节点.
* 设置为 **IMPORTING** 时,节点只接受带有 **ASKING** 的请求,如果客户端没有携带该命令,就会重定向到原来的节点去.

假设我们需要将节点A的 slot 8 迁移到节点B.那我们需要发送两条命令:

- 给B发送 : CLUSTER SETSLOT 8 IMPORTING A
- 给A发送:  CLUSTER SETSLOT 8 MIGRATING B

如此操作后,客户端还是会对key存在于 SLOT 8 的请求给到 A 节点,当该 key 在节点A存在时返回,不存在时会让客户端 `ASKING` Node B 处理.

<img src="https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191127195127.png" alt="key-slot-migrate" style="zoom:50%;" />

此时不会再在节点 A 中创建新 key 了.同时, `redis-trib` 会执行对应的迁移操作.

```bash
CLUSTER GETKEYSINSLOT slot count
```

上述命令会查询出指定 slot 下 count 个需要迁移的key.并对每一个key 执行 `migrate` 命令,将 key 从 A 迁移到 B.该操作为原子操作.

```bash
MIGRATE target_host target_port key target_database id timeout
```

`migrate` 对复杂键也进行了优化,迁移延迟较低,但是在集群中 big key 并不是一个明智的选择.

#### ASK redirection

**ASK** 与 **MOVED** 的区别在于, **MOVED** 可以确定 slot 的确在其他的节点上,下一次查询就直接查重定向后的节点.而 **ASK** 只是将本次查询重定向到指定的节点,接下来的其他查询仍然要请求当前的节点.

**语义**:

* 如果收到一个 **ASK** 重定向,仅将当前查询重定向到指定节点,后续查询仍指向当前节点.
* 使用 **ASKING** 进行重定向查询
* 还不能更新本地客户端的 slot -> node 缓存映射关系

当 slot 迁移完成后,节点 A 会发送 **MOVED** 消息,客户端就可以永久的将 slot 8 的请求指定到新的 ip:port.

### 容错 Fault Tolerance

#### 心跳 & Gossip

Redis Cluster 节点会持续的交换 ping/pong 信息,两种信息没有本质区别,就是 `message type` 不同.下文我们统称 ping/pong 为 **心跳包** (`heartbeat packets`)

通常来说,PING一下就要触发一次 PONG 回复.但也并不全对,节点也可能就把 PONG 信息(包含了自己的配置)发给其他节点就不管了,这样的好处是可以尽快广播新的配置.

通常,一个节点每秒会随机的 PING 几个节点,所以每个节点发出PING 包的数量是恒定的(收到 PONG 包的数量也是恒定的) ,而不去理会节点的数量了. **去中心化**

每个节点会确保给没有 PING 过的节点和超过一半 `NODE_TIMEOT` 没有收到 PONG 的节点发送 PING 消息.`NODE_TIMEOUT` 过后,节点还会尝试重连没响应的节点,确保是因为网络问题才不可达的.

如果将 `NODE_TIMEOUT` 设置为较小的数字,并且节点数非常大,则全局交换的消息数会相当大,因为每个节点都将尝试对超过一半 `NODE_TIMEOUT` 还未刷新信息的其他节点发送 PING.

#### 心跳包结构

结构如下,源码注释就很详细了:

```c
typedef struct {
    char sig[4];        /* Signature "RCmb" (Redis Cluster message bus). */
    uint32_t totlen;    /* Total length of this message */
    uint16_t ver;       /* Protocol version, currently set to 1. */
    uint16_t port;      /* TCP base port number. */
    uint16_t type;      /* Message type */
    uint16_t count;     /* Only used for some kind of messages. */
    uint64_t currentEpoch;  /* The epoch accordingly to the sending node. */
    uint64_t configEpoch;   /* The config epoch if it's a master, or the last
                               epoch advertised by its master if it is a
                               slave. */
    uint64_t offset;    /* Master replication offset if node is a master or
                           processed replication offset if node is a slave. */
    char sender[CLUSTER_NAMELEN]; /* Name of the sender node */
    unsigned char myslots[CLUSTER_SLOTS/8];
    char slaveof[CLUSTER_NAMELEN];
    char myip[NET_IP_STR_LEN];    /* Sender IP, if not all zeroed. */
    char notused1[34];  /* 34 bytes reserved for future usage. */
    uint16_t cport;      /* Sender TCP cluster bus port */
    uint16_t flags;      /* Sender node flags */
    unsigned char state; /* Cluster state from the POV of the sender */
    unsigned char mflags[3]; /* Message flags: CLUSTERMSG_FLAG[012]_... */
    union clusterMsgData data;
} clusterMsg;

typedef struct {
    char nodename[CLUSTER_NAMELEN];
    uint32_t ping_sent;
    uint32_t pong_received;
    char ip[NET_IP_STR_LEN];  /* IP address last time it was seen */
    uint16_t port;              /* base port last time it was seen */
    uint16_t cport;             /* cluster port last time it was seen */
    uint16_t flags;             /* node->flags copy */
    uint32_t notused1;
} clusterMsgDataGossip;
```

