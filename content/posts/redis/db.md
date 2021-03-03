---
title: "Redis-数据库长什么样?"
date: 2019-11-06T11:00:32+08:00
draft: false
tags: ["redis"]
categories: ["redis"]
description: "「Redis 学习笔记」| redis db | 数据库结构"
featured_image:
---

<!--more-->

## 服务器中的数据库

redis的数据库是保存在一个db数组中的,默认会新建16个数组.

```c
# src/server.h
struct redisServer {
  ...
  redisDb *db; // db 存放的数组
  int dbnum; /* 根据该属性决定创建数据库数量 默认: 16 */
  ...
}
```

## 切换数据库

`redis` 数据库从 0 开始计算,通过 `select` 命令切换数据库. `client` 会有一个属性指向当前选中的 DB.

```c
# src/server.h
typedef struct client {
  ...
  redisDb *db; /* 指向当前选中的redisDb */
  ...
}
```

![redis设计与实现-指向当前选中db图例](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191106112623.png)

## 键空间

`redisDb` 的结构是怎样的呢?

```c
# src/server.h
/* Redis database representation. There are multiple databases identified
 * by integers from 0 (the default database) up to the max configured
 * database. The database number is the 'id' field in the structure. */
typedef struct redisDb {
    dict *dict;                 /* 键空间 */
    dict *expires;              /* Timeout of keys with a timeout set */
    dict *blocking_keys;        /* Keys with clients waiting for data (BLPOP)*/
    dict *ready_keys;           /* Blocked keys that received a PUSH */
    dict *watched_keys;         /* WATCHED keys for MULTI/EXEC CAS */
    int id;                     /* Database ID */
    long long avg_ttl;          /* Average TTL, just for stats */
    list *defrag_later;         /* List of key names to attempt to defrag one by one, gradually. */
} redisDb;
```

`键空间` 指的是每一个数据库中存放用户设置键和值的地方. 可以看到上述结构中, `dict` 属性就是每一个数据库的键空间, 字典结构, 也就是我们命令的执行结构.例如 `set msg "hello world~"` .

所以针对数据库的操作就是操作字典.

### 读写键空间后的操作

1. 维护 `hit`, `miss` 次数, 可以利用 `info stats` 查看 `keyspace_hits` 以及 `keyspace_misses`
2. 读取一个键后会更新键的 `LRU` ,用于计算键的闲置时间 `object idletime {key}` 查看
3. 服务器读取一个键后发现已经过期,则会删除这个键在执行其他操作
4. 如果客户端 `watch` 了某个键, 该键修改之后,会被标记为 `dirty`, 从而事务程序可以注意到该键已经被修改了
5. 服务器每修改一个键后, 都会对 `dirty` 计数器 +1 ,这个计数器会触发服务器的持久化和复制操作
6. 服务器开启数据库通知之后,键修改后会发送相应的数据库通知

### 过期时间保存

上述的 `redisDb` 结构中有 `expires` 的字典, `redis` 就是将我们设置的过期时间存到了这个字典中.键就是数据库键,值是一个 `long long` 类型的整数, 保存了键的过期时间: 一个毫秒精度的 `UNIX` 时间戳.

## Redis的过期键删除策略

有这么三种删除方式.

### 定时删除

设置键过期时间的同时,创建一个定时器,到期自动删除

#### 优点

内存友好,键过期就删除

#### 缺点

1. 对 CPU 不友好,过期键较多时,会占用较长时间,CPU 资源紧张的情况下会影响服务器的响应时间和吞吐量
2. 创建定时器需要用到 `redis` 的时间事件,实现方式为无序链表,查找效率低

### 惰性删除

无视键是否过期,每次从键空间取键时,先判断是否过期,过期就删除,没过期就返回.

#### 优点

对 CPU 友好,遇到过期键才删除

#### 缺点

如果过期键很多,且一直不会被访问,就会导致大量内存被浪费

### 定期删除

定期的在数据库中检查,删除过期的键.定期删除策略是上面两种策略的折中方案.

#### 优点

1. 每隔一段时间删除过期键,可以减少删除操作对 CPU 的影响
2. 定期删除也可以减少过期键带来的内存浪费

#### 难点

确定删除操作执行的时长和频率

### redis采用方案

**惰性删除 + 定期删除**

惰性删除是在所有读写数据库命令执行之前检查键是否过期来实现的.

定期删除是通过 `redis` 的定时任务执行.在规定的时间内,多次遍历服务器的各个数据库,从 `expires` 字典中 **随机抽查** 一部分键的过期时间.`current_db` 会记录当前函数检查的进度,并在下一次函数执行时,接着上次的执行.循环往复地执行.

## 内存淘汰策略

默认策略是 `volatile-lru`，即超过最大内存后，在过期键中使用 lru 算法进行 key 的剔除，保证不过期数据不被删除，但是可能会出现 OOM 问题。

##### 其他策略如下：

- allkeys-lru：根据 LRU 算法删除键，不管数据有没有设置超时属性，直到腾出足够空间为止。
- allkeys-random：随机删除所有键，直到腾出足够空间为止。
- volatile-random: 随机删除过期键，直到腾出足够空间为止。
- volatile-ttl：根据键值对象的 ttl 属性，删除最近将要过期数据。如果没有，回退到 noeviction 策略。
- noeviction：不会剔除任何数据，拒绝所有写入操作并返回客户端错误信息 "(error) OOM command not allowed when used memory"，此时 Redis 只响应读操作。

## AOF,RDB & 复制功能对过期键的处理

1. 生成 `RDB` 文件时,过期键不会被保存到新文件中
2. 载入 `RDB` 文件
   1. 以主服务器运行:未过期的键被载入,过期键忽略
   2. 以从服务器运行:保存所有键,无论是否过期.由于主从服务器在进行数据同步时,从服务器数据库就会被清空,所以一般来讲,也不会造成什么影响.
3. `AOF` 写入时,键过期还没有被删除,`AOF` 文件不会受到影响,当键被惰性删除或被定期删除后,`AOF` 文件会追加一条 `DEL` 命令来显示记录该键已被删除
4. `AOF` 重写时,会对键过期进行确认,过期补充些.
5. 复制模式下,从服务器的过期键删除由主服务器控制.
   1. 主服务器删除一个键后,会显示发送 `DEL` 命令给从服务器.
   2. 从服务器接收读命令时,如果键已过期,也不会将其删除,正常处理
   3. 从服务器只在主服务器发送 `DEL` 命令才删除键

主从复制不及时怎么办?会有脏读现象~

## 数据库通知

通过订阅的模式,可以实时获取键的变化,命令的执行情况.通过 `redis` 的 `pub/sub` 模式来实现.命令对数据库进行了操作后,就会触发该通知,置于能不能发送出去完全看你的配置了.

`notify_keyspace_events` 系统配置决定了服务器发送的配置类型.如果给定的 `type` 不是服务器允许发送的类型,程序就直接返回了.然后就判断能发送键通知就发送,能发送命令通知就发送.	

```c

/* The API provided to the rest of the Redis core is a simple function:
 *
 * notifyKeyspaceEvent(char *event, robj *key, int dbid);
 *
 * 'event' is a C string representing the event name.
 * 'key' is a Redis object representing the key name.
 * 'dbid' is the database ID where the key lives.  */
void notifyKeyspaceEvent(int type, char *event, robj *key, int dbid) {
    sds chan;
    robj *chanobj, *eventobj;
    int len = -1;
    char buf[24];

    /* If any modules are interested in events, notify the module system now. 
     * This bypasses the notifications configuration, but the module engine
     * will only call event subscribers if the event type matches the types
     * they are interested in. */
     moduleNotifyKeyspaceEvent(type, event, key, dbid);
    
    /* If notifications for this class of events are off, return ASAP. */
    if (!(server.notify_keyspace_events & type)) return;

    eventobj = createStringObject(event,strlen(event));

    /* __keyspace@<db>__:<key> <event> notifications. */
    if (server.notify_keyspace_events & NOTIFY_KEYSPACE) {
        chan = sdsnewlen("__keyspace@",11);
        len = ll2string(buf,sizeof(buf),dbid);
        chan = sdscatlen(chan, buf, len);
        chan = sdscatlen(chan, "__:", 3);
        chan = sdscatsds(chan, key->ptr);
        chanobj = createObject(OBJ_STRING, chan);
        pubsubPublishMessage(chanobj, eventobj);
        decrRefCount(chanobj);
    }

    /* __keyevent@<db>__:<event> <key> notifications. */
    if (server.notify_keyspace_events & NOTIFY_KEYEVENT) {
        chan = sdsnewlen("__keyevent@",11);
        if (len == -1) len = ll2string(buf,sizeof(buf),dbid);
        chan = sdscatlen(chan, buf, len);
        chan = sdscatlen(chan, "__:", 3);
        chan = sdscatsds(chan, eventobj->ptr);
        chanobj = createObject(OBJ_STRING, chan);
        pubsubPublishMessage(chanobj, key);
        decrRefCount(chanobj);
    }
    decrRefCount(eventobj);
}
```



