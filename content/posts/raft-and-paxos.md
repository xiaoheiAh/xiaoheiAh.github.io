---
title: "分布式一致性算法介绍"
date: 2020-01-14T14:06:18+08:00
draft: true
tags: ["HA","一致性算法"]
categories:
featured_image: 
---

<!--more-->

## CAP 理论

> https://www.cnblogs.com/xrq730/p/4944768.html

无法同时满足 **C：Consistency** - 一致性，**A：Availability** - 可用性， **P：Partition tolerance** - 分区容错性

并且分区容错性是分布式系统多节点部署的关键，属于不能割舍的，如果只有 CA 那其实就是单机数据库的场景了，所以业内基本都是  CP/AP 的组合。

## BASE 理论

BASE是Basically Available（基本可用）、Soft state（软状态）和Eventually consistent（最终一致性）三个短语的缩写。核心思想：**即使无法做到强一致性，但每个应用都可以根据自身业务特点，采用适当的方式来使系统达到最终一致性**。



## 一致性协议 2PC/3PC/Paxos

https://www.hollischuang.com/archives/681

https://matt33.com/2018/07/08/distribute-system-consistency-protocol/  :+1:

### 2PC

协调者来控制链路下所有参与者的提交与回滚。

* 第一阶段（准备阶段）：协调者给所有参与者发送 prepare 消息，每个参与者执行事务但不提交，同时写入 redolog 和 undolog，最后返回成功或失败

* 第二阶段（提交阶段）：协调者收到参与者失败或者超时，则直接向每个参与者发送回滚否则发送提交。参与者执行回滚或提交操作，并释放所有事物处理过程中的锁资源。
  * 回滚通过 undolog 来实现

#### 缺点

1. 同步阻塞/吞吐量低
2. 协调者单点故障
3. 数据不一致：提交阶段时，协调者发送 commit 给参与者，由于网络异常导致一部分参与者收不到消息。整个系统数据就无法移植了
4. 协调者发送 commit 后宕机，接收消息的参与者也宕机就没有人知道这个事务是否已提交了

### 3PC

是 **2PC** 的改进版，改进点主要在于：

1. 引入超时机制。同时在协调者和参与者中都引入超时机制。
2. 在第一阶段和第二阶段中插入一个准备阶段。保证了在最后提交阶段之前各参与节点的状态是一致的。

#### 过程

* 第一阶段 Can Commit: 协调者询问参与者是否可提交，参与者返回能还是不能
* 第二阶段 Pre Commit: 如果 Can Commit 阶段的结果为 **能** 就通知所有参与者执行事务了，记录 redo，undolog，并且向协调者返回 ack 通知。如果是 **不能** 就通知所有参与者中断事务。如果超时未收到协调者的请求也执行事务中断。
* 第三阶段 Do Commit 通知所有参与者提交，如果超时未收到二阶段通知也通知所有参与者回滚。
  * 在该阶段如果参与者超时未收到协调者的 commit 消息，会自行 commit。因为理论上进入第三阶段意味着 preCommit 是正常的，也意味着第一阶段所有参与者是同一提交的，成功的概率比较大。因此自动提交了。

#### 问题

如果参与者超时自行中断，协调者怎么知道该参与者是否有中断呢？

与 **2PC** 一样存在网络分区问题，如果 preCommit 阶段协调者发送消息后，出现网络分区，此时参与者仍能正常 commit，而协调者收不到 ack 就想中止事务，但没有用了。



## Paxos

> http://codemacro.com/2014/10/15/explain-poxos/ :+1:
>
> https://matt33.com/2018/07/08/distribute-system-consistency-protocol :+1:
>
> [Paxos 中文 wiki](https://zh.wikipedia.org/zh-cn/Paxos算法#.E5.AE.9E.E4.BE.8B)



### 概览

### 原理

### 异常处理

## Raft

> 参考
>
> 1. https://raft.github.io/
> 2. https://www.codedump.info/post/20180921-raft/
> 3. https://www.cnblogs.com/xybaby/p/10124083.html  推荐看这个 :+1:
> 4. https://www.cnblogs.com/mindwind/p/5231986.html

### 概览

Raft算法由leader节点来处理一致性问题。leader节点接收来自客户端的请求日志数据，然后同步到集群中其它节点进行复制，当日志已经同步到超过半数以上节点的时候，leader节点再通知集群中其它节点哪些日志已经被复制成功，可以提交到raft状态机中执行。

### 原理

#### 术语

##### Leader/Follower/Candidate

Leader 统筹全局，负责接收客户端的命令，写入本地的日志并且广播给所有 Follower 将命令写入其本地日志，与 Follower 维持心跳维持统治。

Follower 作为 Leader 的跟随者，Leader 干啥他就干啥，就是镜像复制的感觉。如果 Leader 与 Follower 心跳超时，Follower 会选择将任期 +1 发起选举投票晋升为 Candidate 。

Candidate 是候选人的意思，这是个临时角色，最终都会转变为 Leader 或者降级为 Follower。Follower 发起选举时就会成为一个 Candidate，如果超过半数投给了自己，就晋升为 Leader 了。如果收到了一个大于自己的任期消息或者 Leader 的消息，说明有人已经成为 Leader 了那么就降为 Follower 跟随这个 Leader。如果在偶数节点的情况下，是可能存在每个节点投票数相同的，此时就继续保持 Candidate 身份，发起下一次投票。

##### 任期

每一个任期（`Term`）都会选举出一个 Leader 领导数据的更新

#### 特征

- 选举安全性（`Election Safety`）：在一个任期内只能存在最多一个leader节点。
- Leader节点上的日志为只添加（`Leader Append-Only`）：leader节点永远不会删除或者覆盖本节点上面的日志数据。
- 日志匹配性（`Log Matching`）：如果两个节点上的日志，在日志的某个索引上的日志数据其对应的任期号相同，那么在两个节点在这条日志之前的日志数据完全匹配。
- leader完备性（`Leader Completeness`）：如果一条日志在某个任期被提交，那么这条日志数据在leader节点上更高任期号的日志数据中都存在。
- 状态机安全性（`State Machine Safety`）：如果某个节点已经将一条提交过的数据输入raft状态机执行了，那么其它节点不可能再将相同索引的另一条日志数据输入到raft状态机中执行。

#### 选举流程

半数投票！

一个节点给另一个节点投票的一个条件：被选举的节点必须比本节点日志更新，否则拒绝。这样可以保证产生的  Leader 有最新的数据。

判断日志新旧的依据：对比最后一条日志的任期号，相同则比较索引号

每个 Follower 会伴随一个选举超时定时器，超时时间是随机的，一般在 150~300 ms 之间，可以保证节点之间尽量不同时超时发起选举。

#### 读请求的处理

1. leader节点需要有当前已提交日志的信息。在前面提到过不能提交前面任期的日志条目，因此一个新leader产生之后，需要提交一条空日志，这样来确保上一个任期内的日志全部提交。
2. leader节点保存该只读请求到来时的commit日志索引为readIndex，
3. leader需要确认自己当前还是集群的leader，因为可能会由于有网络分区的原因导致leader已经被隔离出集群而不自知。为了达到这个目的，leader节点将广播一个heartbeat心跳消息给集群中其它节点，当收到半数以上节点的应答时，leader节点知道自己当前还是leader，同时readIndex索引也是当前集群日志提交的最大索引。

### 异常处理

只有 Leader 能写，请求到 follower 的写都会重定向到 Leader 上。那 Leader 的压力不久很大了吗？

##### 网络分区

**6 个节点一边分一半，那不是就形成了两个可用的集群了吗？完全脑裂了。**