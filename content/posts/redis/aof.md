---
title: "Redis-AOF持久化"
date: 2019-11-08T15:18:05+08:00
draft: false
tags: ["redis"]
categories: ["redis"]
description: "「Redis 学习笔记」| 持久化机制 | AOF"
featured_image:
---

`RDB` 和 `AOF` 区别在于: 前者保存数据库快照,持久化所有键值对,后者通过保存 **写命令** 保证数据库的状态.

<!--more-->

## 什么是 AOF ?

`AOF` 持久化通过保存服务器执行的写命令实现,进行恢复时通过重放 `AOF` 文件中的写命令,来保证数据安全.就像 `mysql` 的 `binlog` 一样.

### 开启 AOF

通过在 `redis.conf` 中将 `appendonly` 设为 `yes` 即可

```bash
# redis.conf
appendonly yes
# 设置 aof 文件名字
appendfilename "appendonly.aof"
# Redis支持三种不同的刷写模式：
# appendfsync always #每次收到写命令就立即强制写入磁盘，是最有保证的完全的持久化，但速度也是最慢的，一般不推荐使用。
appendfsync everysec #每秒钟强制写入磁盘一次，在性能和持久化方面做了很好的折中，是受推荐的方式。
# appendfsync no     #完全依赖OS的写入，一般为30秒左右一次，性能最好但是持久化最没有保证，不被推荐。
```

### AOF 文件格式

`AOF` 文件格式以 `redis` 命令请求协议为标准的,`*.aof` 文件可以直接打开.

![redis设计与实现-aof格式](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191112184639.png)

### AOF 持久化过程

#### 命令追加 append

`redis` 执行完客户端的写命令后,会将该命令以协议的格式写入到 `aof_buf` 中.该属性为 `redisServer` 中的一个.

```c
#src/server.h
struct redisServer {
 ....
 sds aof_buf;      /* AOF buffer, written before entering the event loop */
}
```

#### AOF 写入同步

`redis` 的服务进程是一个 **事件循环** - `event loop` , 每次循环大概会做三件事.

1. 文件事件: 接收客户端的命令,返回结果
2. 时间事件: 执行系统的定时任务(`serverCron`), 完成渐进 `rehash` 扩容之类的操作
3. aof flush: 是否将 `aof_buf` 中的内容写入文件中

```bash
# 伪代码
def eventloop():
 while true:
 	processFileEvents() # 处理命令
 	processTimeEvents() # 处理定时任务
 	flushAppendOnlyFile() # 处理 aof 写入
 	
```

`flushAppendOnlyFile` 中的动作是否执行是根据一个配置决定的.

#####  appendfsync

该配置有几个值可选,默认是 `everysec`.

1. always: 总是写入.只要程序执行到这一步了,就将 `aof_buf` 中命令协议写入到文件
2. everysec: 每秒写入. 每次执行前会先判断是否与上次写入间隔一秒,再次同步时通过 **一个线程** 专门执行
3. no: 不写入. 命令写入 `aof_buf` 后由操作系统决定何时同步到文件

> fsync: 现代操作系统为了提高文件读写的效率,通常会将 `write` 函数写入的数据缓存在内存中,等到缓存空间填满或者超过一定时限,再将其写入磁盘.这样的问题在于宕机时缓存中的数据就无法恢复.所以操作系统提供了 **fsync/fdatasync** 两个函数,强制操作系统将数据立即写入磁盘,保证数据安全.两函数区别在于: 前者会更新文件的属性,后者只更新数据.

三种模式在性能和数据上都有相对的优缺点. `always` 模式数据安全性更强,毕竟每次都是直接写入,但是就会影响性能.磁盘读写是比较慢的. `everysec` 模式性能较好,但会丢失一秒内的缓存数据. `no` 模式就完全取决于操作系统了.

#### AOF 还原数据

![redis设计与实现-aof还原数据](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191113182005.png)

### AOF 重写

`AOF` 重写的意思其实就是对单个命令的多个操作进行整理,留下最终态的执行命令来减少 `aof` 文件的大小.你可以想象一下执行 1w 次 `incr` 操作,写入 `aof` 1w 次的场景.

#### 触发条件

`AOF` 重写可以自动触发.通过配置 `auto-aof-rewrite-min-size` 和`auto-aof-rewrite-percentage`,满足条件就会自动重写.具体可以查看官方的 `redis.conf`

#### 重写过程

1. 创建子进程，根据内存里的数据重写`aof`，保存到`temp`文件
2. 此时主进程还会接收命令，会将写操作追加到旧的`aof`文件中，并保存在`server.aof_rewrite_buf_blocks`中，通过管道发送给子进程存在`server.aof_child_diff`中，最后追加到`temp`文件结尾
3. 子进程重写完成后退出，主进程根据子进程退出状态，判断成功与否。成功就将剩余的`server.aof_rewrite_buf_blocks`追加到`temp file`中，然后`rename()`覆盖原`aof`文件

重写的过程中主进程还是会一直接受客户端的命令,所以重写子进程与主进程肯定会存在数据不一致的情况.`redis`针对这种情况作出了解决方案: 新增一个 `aof_rewrite_buf_blocks`, `aof` 写入命令时,不仅写入到 `aof_buf`, 如果正在重写,那么也写入到 `aof_rewrite_buf_blocks` 中,这样在子进程重写完毕后,可以将 `aof_rewrite_buf_blocks` 的命令追加到新文件中,保证数据不丢失.

`rename` 操作是原子的,也是唯一会造成主进程阻塞的操作.



## 参考

1. https://redis.io/topics/persistence
2. https://youjiali1995.github.io/redis/persistence/

