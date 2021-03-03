---
title: "Redis-分布式锁"
date: 2019-11-03T14:49:56+08:00
draft: false
tags: ["分布式锁","redis"]
categories: ["redis"]
description: "「Redis 学习笔记」| 分布式锁"
featured_image:
---

分布式锁有很多中实现(纯数据库,zookeeper,redis),纯数据库的受限于数据库性能,zk 可以保证加锁的顺序,是公平锁.Redis中的实现就是接下来要学习的.

<!--more-->

## 为什么使用分布式锁?

在分布式环境下想要保证只能有一个请求更新一条数据,普通的加锁(比如 Java 中的 `synchronized`,`JUC` 中的各种 `Lock`)都不能胜任. 分布式锁的意义在于可以将操作锁的权利中心化,从而串行控制业务的执行.但是使用分布式锁也有很多弊端,后面再说.

### 分布式锁的特点?

1. **互斥:**具有强排他性,需要保证不同节点不同线程的互斥
2. **可重入:**同一个节点的同一个线程如果获得了锁,那也可以再次获得
3. **高效,高可用:**加锁解锁要高效,高可用保证分布式锁服务不会宕机失效
4. **阻塞/非阻塞:**像 `ReentrantLock` 支持 `lock`, `tryLock`, `tryLock(long timeout)`
5. **支持公平锁/非公平锁(Option)**

## 如何使用分布式锁?

Redis中有多种实现分布式锁的方式,一个一个看看.

### 简单粗暴版

设置一个坑,让所有节点去抢就好.即语义为: `set if not exist`, 抢到后执行逻辑,逻辑完成后在`del`即可.

`redis 2.8` 版本之前我们会通过以下方式:

```
setnx {resource-name} {anystring}
```

 我们还需要加一个过期时间,以免各种异常宕机情况导致锁无法释放的问题.

```bash
expire key {max-lock-time}
```

这两条命令并不是原子操作的,所以我们需要通过 `Lua` 脚本来保证其原子性

`redis 2.8` 版本之后官方提供了 nx ex 的原子操作,使用起来更加简单了.

```bash
set {resource-name} {anystring} nx ex {max-lock-time}
```

### Redission版

> https://github.com/redisson/redisson

`Redission` 和 `Jedis` 都是 Java 中的 redis 客户端, `Jedis` 使用的是阻塞式 I/O, 而 `Redission` 使用的 `Netty` 来进行通信,而且 API 封装更友好, 继承了 `java.util.concurrent.locks.Lock` 的接口,可以像操作本地 `Lock` 一样操作分布式锁. 而且 `Redission` 还提供了不同编程模式的 API: `sync/async`, `Reactive`, `RxJava`, 非常人性化. `Redission` 有丰富的接口实现以及对不同异常情况的处理设计很值得学习.

```java
// 1. 设置 config
Config config = new Config();
// 2. 创建 redission 实例
RedissonClient redisson = Redisson.create(config);
// 4. 获取锁
RLock lock = redisson.getLock("myLock");
// 5. 加锁
// 方式一
// 加锁以后10秒钟自动解锁
// 无需调用unlock方法手动解锁
lock.lock(10, TimeUnit.SECONDS);
// 方式二
// 尝试加锁，最多等待100秒，上锁以后10秒自动解锁
boolean res = lock.tryLock(100, 10, TimeUnit.SECONDS);
if (res) {
   try {
     ...
   } finally {
       lock.unlock();
   }
}
// 方式三
// 异步加锁
RLock lock = redisson.getLock("anyLock");
lock.lockAsync();
lock.lockAsync(10, TimeUnit.SECONDS);
Future<Boolean> res = lock.tryLockAsync(100, 10, TimeUnit.SECONDS);
```

### RedLock

> https://redis.io/topics/distlock

上述的分布式锁实现都是基于单实例实现,所以会出现单点问题.胆大`RedLock` 基本原理是利用多个 `Redis` 集群，用多数的集群加锁成功，减少Redis某个集群出故障，造成分布式锁出现问题的概率。

#### 加锁过程

1. 客户端获取当前的时间戳。
2. 对 N 个 Redis 实例进行获取锁的操作，具体的操作同单机分布式锁。对 Redis 实例的操作时间需要远小于分布式锁的超时时间，这样可以保证在少数 Redis 节点 Down 掉的时候仍可快速对下一个节点进行操作。
3. 客户端会记录所有实例返回加锁成功的时间，只有从多半的实例（在这里例子中 >= 3）获取到了锁，且操作的时间远小于分布式锁的超时时间，锁才被人为是正确获取。
4. 如果锁被成功获取了，当前分布式锁的合法时间为初始设定的合法时间减去上锁所花的时间。
5. 若分布式锁获取失败，会强制对所有实例进行锁释放的操作，即使这个实例上不存在相应的键值。



## 分布式锁的一些问题

### 锁被其他客户端释放

如果线程 A 在获取锁后处理业务时间过长,导致锁被自动释放了,此时 线程 B 重新获取到了锁. 线程 A 在执行完业务逻辑后释放锁(`DEL`操作),这是就会把线程 B 获取到的锁给释放掉.

#### 如何解决?

在设置 `value` 时,生成一个随机 token, 删除 key 时先做判断,只有在 token 与自己持有的相等时,才能删除. 由于需要保证原子性, 我们需要通过 `Lua` 脚本来实现.像下面这样,不过 `Redission` 已经有对应的实现了.

```lua
if redis.call("get",KEYS[1]) == ARGV[1] then
    return redis.call("del",KEYS[1])
else
    return 0
end
```

### 超时问题

如果在加锁和释放锁之间的业务逻辑过长,超出了锁的过期时间,那么就可能会导致另一个线程获取到锁,导致逻辑不能严格的串行执行.所以分布式锁的初衷是: 逻辑越短越好,持有锁的时间越短越好.

#### 如何解决?

这个目前没有太好解决的方案,后面如果看到了,就更新到这里.自己觉得: 尽量保证持锁时间短,优化代码逻辑.虽然可以延长锁的时间,但是会影响吞吐量的吧.如果真的有多个客户端持有了锁,还需要尽量保证业务逻辑中数据的幂等性,日志监控,及时报警,这样也可以做到尽快的人工介入.

> 技术莫得银弹~适合的才是最好的.

### 时钟不一致

`RedLock` 强依赖时间,所以机器时间不一致会有很大的问题

#### 如何解决?

1. 人为调整
2. NTP自动调整: 可以将时间精度控制在一定范围内.

### 性能、故障恢复和 fsync

假设 Redis 没有持久性，当一个客户端获得了 5 个实例中的 3 个锁，若 3 个锁所在的实例 Down 掉了，实例再次启动时，其他的客户端也可以再次获得锁。

这个问题会因为开启了 Redis 的持久化而改观，对于 AOF 持久化（区别与 RDB 的二进制持久化，是文本持久化）。默认采用的是每秒钟通过 `fsync` 落盘，这意味着会丢失一秒内的数据，如果需要更有安全保证的持久化，可以设置 `fsync=always`，但对应的会损失一部分性能。

更好的解决办法是在实例 Down 掉后延迟一个略长于锁合法时间的时间，这样就可以保证在实例启动起来时锁一定是过期的，从而无须以损失性能为代价而使用 `fsync=always` 的持久化。

## 参考

1. [再有人问你分布式锁，这篇文章扔给他](https://juejin.im/post/5bbb0d8df265da0abd3533a5)
2. [RedLock中译](https://blog.brickgao.com/2018/05/06/distributed-lock-with-redlock/)