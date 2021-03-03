---
title: "Redis-RDB持久化"
date: 2019-11-06T19:08:56+08:00
draft: false
tags: ["redis"]
categories: ["redis"]
description: "「Redis 学习笔记」| 持久化机制 | RDB"
featured_image:
---

`redis` 为内存数据库,一旦服务器进程退出,服务器中的数据就不见了.所以内存中的数据需要持久化的硬盘中来保证可以在必要的时候进行故障恢复. `RDB` 就是 `redis` 提供的一种持久化方式.

<!--more-->

> 官方关于持久化的文章: https://redis.io/topics/persistence

## 什么是 RDB?

`RDB` 是 `redis` 提供的一种持久化方式,可以手动执行,也可以通过定时任务定期执行,可以将某个时间节点的数据库状态保存到一个 `RDB` 文件中,叫做 `dump.rdb`.如果开启了压缩算法( `LZF` )的支持,则可以利用算法减少文件大小.服务器意外宕机或者断电后重启都可以通过该文件来恢复数据库状态.

### 如何执行?

有两个命令可以生成 `RDB` 文件. 

1. **SAVE:** 执行时进程阻塞,无法处理其他命令
2. **BGSAVE:** 新建一个子进程来后台生成 `RDB` 文件

具体实现逻辑在: `src/rdb.c/rdbSave()`,从官方文档可知,该实现是基于 `cow` 的.

> https://redis.io/topics/persistence
>
> This method allows Redis to benefit from copy-on-write semantics.

### 如何载入?

`RDB` 文件会在 `redis` 启动时自动载入.

由于 `AOF` 持久化的实时性更好,所以如果同时开启了 `AOF` , `RDB` 两种持久化,会优先使用 `AOF` 来恢复.

### BGSAVE 执行时的状态

`BGSAVE` 执行期间会拒绝 `SAVE/BGSAVE` 的命令,避免产生 `竞争条件`.

`BGSAVE` 执行期间 `BGREWRITEAOF` 命令会延迟到 `BGSAVE` 执行完之后执行.

`BGREWRITEAOF` 在执行时, `BGSAVE` 命令会被拒绝.

`BGSAVE` 和 `BGREWRITEAOF` 命令的权衡完全是性能方面的考虑.毕竟都会有大量的磁盘写入,影响性能.

## 定时执行BGSAVE

`BGSAVE` 不会阻塞服务器进程,所以 `redis` 允许用户通过配置, 定时执行 `BGSAVE` 命令.

### 快照策略 Snapshotting

可以通过设置 N 秒内至少 M 次修改来触发一次 `BGSAVE`.

```bash
save 60 1000 # 60s内有至少1000次修改时 bgsave 一次
```

#### 默认的保存条件

```bash
save 900 1
save 300 10
save 60 10000
```

### dirty 计数器 & lastsave 属性

`redis` 中维护了一个计数器,来记录距离上一次 `SAVE/BGSAVE` 后服务器对所有数据库进行了多少次增删改,叫做 `dirty计数器`.属于 `redisServer` 结构体的属性之一.

`lastsave` 是记录了上一次成功执行 `SAVE/BGSAVE` 的 `UNIX时间戳` , 同样是 `redisServer` 结构体的属性之一.

```c
# src/server.h
struct redisServer {
  ...
  long long dirty; /* Changes to DB from the last save */
  time_t lastsave; /* Unix time of last successful save */
  ...
}
```

### 定时执行过程

`redis` 有一个定时任务 `serverCron` , 每隔 `100ms` 就会执行一次,用于维护服务器.该任务就会检查 `save` 设置的保存条件是否满足,满足则执行 `BGSAVE`

#### 满足条件逻辑

遍历设置的 `save` 参数, 计算当前时间到 `lastsave` 的间隔 `interval` , 如果 `dirty` > `save.change` & `interval` > `save.seconds` 那么就执行保存

## RDB 文件结构

> https://github.com/sripathikrishnan/redis-rdb-tools/wiki/Redis-RDB-Dump-File-Format
>
> 写下这篇文章时参考版本为 2019.09.05 更新的版本

`RDB` 文件格式对读写进行了很多优化,这类优化导致其格式与内存中存在的形式极其相似,同时利用 `LZF` 压缩算法来优化文件的大小.一般来讲, `redis` 对象都会提前标记自身的大小,所以备份`RDB` 在读取这些 `object` 时,可以提前知道要分配多少内存.

### 解析RDB结构

下面的代码展示的是 16 进制下 `RDB` 文件的结构,便于理解

```bash
----------------------------# RDB is a binary format. There are no new lines or spaces in the file.
52 45 44 49 53              # 魔数 REDIS的16进制表示,代表这是个RDB文件
30 30 30 37                 # 4位ascii码表示当前RDB版本号,这里表示"0007" = 7
----------------------------
FE 00                       # FE 表明这是数据库选择标记. 00 表示选中0号数据库
----------------------------# Key-Value pair starts
FD $unsigned int            # FD 是秒级过期时间的标记. 紧接着是 4 byte unsigned int 过期时间
$value-type                 # 1 byte 标记 value 类型 - set, map, sorted set etc.
$string-encoded-key         # 经过编码后的键
$encoded-value              # 值,编码格式取决去 $value-type
----------------------------
FC $unsigned long           # FC 表明是毫秒级过期时间. 过期时间值是 8 bytes的 unsigned long,是一个unit时间戳
$value-type                 # 同上秒级时间
$string-encoded-key         # 同上秒级时间
$encoded-value              # 同上秒级时间
----------------------------
$value-type                 # 这一栏是没有过期时间的key-value
$string-encoded-key
$encoded-value
----------------------------
FE $length-encoding         # 前一个数据库的编码完成,选择新的数据库进行处理.数据库编号会根据 length-encoding 格式获得
----------------------------
...                         # Key value pairs for this database, additonal database
                            
FF                          ## 表明 RDB 文件结束了 
8 byte checksum             ## 8byte CRC 64 校验码
```

#### value type

1 byte 表示了 `value` 的类型.

| type(以下为十进制表示) | 编码类型              |
| ---------------------- | --------------------- |
| 0                      | String                |
| 1                      | List                  |
| 2                      | Set                   |
| 3                      | Sorted Set            |
| 4                      | Hash                  |
| 9                      | Zipmap                |
| 10                     | Ziplist               |
| 11                     | Intset                |
| 12                     | Sorted Set in Ziplist |
| 13                     | HashMap in Ziplist    |

#### 键值编码格式

键(`key`)都是字符串,所以使用`string` 编码格式.

值(`value`)就会有不同的区分:

* 如果 `value type` 为 0 ,会是简单的字符串.
* 如果 `value type` 为 9,10,11,12, 值会被包装为 `string`, 在读到该字符串后,会进一步解析.
* 如果 `value type` 为 1,2,3,4, 值会是一个字符串数组.

### Length Encoding

长度编码是用来存储对象的长度的.是一种可变字节码,旨在使用尽可能少的字节.

#### 如何工作?

1. 从流中读取 1byte,得到高两位.
2. 如果是 `00` 开头, 那么剩下 6 位表示长度
3. 如果是 `01` 开头, 会再从流中读取 1byte,合起来总共 14 位作为长度.
4. 如果是 `10` 开头, 会直接丢弃剩下的 6 位.再从流中读取 4bytes作为长度.
5. 如果是 `11` 开头, 说明这个对象是一种特殊编码格式. 剩下的 6 位表示了它的格式类型.这个编码通常用来将数字存储为字符串,或者存储被编码过得字符串([String Encoding](#String-Encoding)).

#### 编码结果是?

从上述可得,可能的编码格式是这样的:

1. 1 byte 最多存储到 63
2. 2 bytes 最多存储到 16383
3. 5 bytes 最多存储到 2^32 - 1

### String Encoding

`redis` 的字符串是二进制安全的,所以可以存储 anything. 没有任何字符串结尾的标记.最好将 `redis` 字符串视为一个字节数组.

有三种类型的字符串:

1. 长度编码字符串

   这是最简单的一种,字符串的长度会利用 `Length Encoding` 编码作为前缀,后面跟着字符串的编码

2. 数字作为字符串

   这里就将上面 [Length Encoding](#Length-Encoding) 的特殊编码格式联系起来了,数字作为字符串时以 `11` 开头,剩下的 6 位表示不同的数字类型

   * 0 表示接下来是一个 8 位数字
   * 1 表示接下来是一个 16  位数字
   * 2 表示接下来是一个 32 位数字

3. 压缩字符串

   压缩字符串的 `Length Encoding` 还是以 `11` 开头的, 但是剩下的6 位二进制的值为 4, 表明后面读取到的是一个压缩字符串.压缩字符串会存储压缩前和压缩后的长度.解析规则如下:

   * 根据 `Length Encoding` 读取压缩的长度 `clen`
   * 根据 `Length Encoding` 读取未压缩的长度
   * 从流中读取 `clen` bytes 的数据
   * 利用 `LZF` 算法进行解析

## 分析RDB文件

利用 `od` 命令来分析来看看 `rdb` 文件长什么样子.我将 `redis` 数据库清空后,执行了 `set msg hello`,所以现在只有一个键 `msg`, 值为 `hello`.下面的命令第一行输出的是 16 进制,下面一行输出的是对应的 `ascii`. 下面进行解析~

```bash
➜ od -A x -t x1c -v dump.rdb
0000000    52  45  44  49  53  30  30  30  39  fa  09  72  65  64  69  73
           R   E   D   I   S   0   0   0   9 372  \t   r   e   d   i   s
0000010    2d  76  65  72  05  35  2e  30  2e  34  fa  0a  72  65  64  69
           -   v   e   r 005   5   .   0   .   4 372  \n   r   e   d   i
0000020    73  2d  62  69  74  73  c0  40  fa  05  63  74  69  6d  65  c2
           s   -   b   i   t   s 300   @ 372 005   c   t   i   m   e 051
0000030    29  e8  c3  5d  fa  08  75  73  65  64  2d  6d  65  6d  c2  d0
           ) 350 303   ] 372  \b   u   s   e   d   -   m   e   m 302 007
0000040    07  10  00  fa  0c  61  6f  66  2d  70  72  65  61  6d  62  6c
          \a 020  \0 372  \f   a   o   f   -   p   r   e   a   m   b   l
0000050    65  c0  00  fe  00  fb  01  00  00  03  6d  73  67  05  68  65
           e 300  \0 376  \0 373 001  \0  \0 003   m   s   g 005   h   e
0000060    6c  6c  6f  ff  fc  0e  6b  79  fe  47  1a  36
           l   l   o 377 374 016   k   y 376   G 032   6
000006c
```

### 魔数和版本号

前 5 个字节就是我们看到的 `REDIS`,以及后四个字节对应的版本号`9`

### 辅助字段 Aux Fields

这是 `Version 7` 之后加入的字段, `Redis设计与实现` 所使用的版本是没有这个,所以一开始有点懵~ 只能看代码了.

```c
# src/rdb.c
/* 该函数负责执行 RDB 文件的写入 */
int rdbSave(char *filename, rdbSaveInfo *rsi) {
	//伪代码
  1. 创建一个临时文件 temp-$pid.rdb,并处理创建失败的逻辑
  2. 新建一个redis封装的I/O流
  3. 写入rdb文件 rdbSaveRio()
  4. 将文件重命名, 默认重命名为 dump.rdb
  5. 更新服务器的一些状态: dirty计数器置0,更新lastsave等
}
```

然后我们来看下写入的 `Aux Fields`, 在函数 `rdbSaveRio` 中

```c
int rdbSaveRio(rio *rdb, int *error, int flags, rdbSaveInfo *rsi) {
	 // 忽略所有只看重点
   if (server.rdb_checksum)
        rdb->update_cksum = rioGenericUpdateChecksum; // 生成校验码
    snprintf(magic,sizeof(magic),"REDIS%04d",RDB_VERSION); // 生成魔数及版本号
    if (rdbWriteRaw(rdb,magic,9) == -1) goto werr; // 写入魔数及版本号
    if (rdbSaveInfoAuxFields(rdb,flags,rsi) == -1) goto werr; // 写入 AuxFileds
}

/* Save a few default AUX fields with information about the RDB generated. */
int rdbSaveInfoAuxFields(rio *rdb, int flags, rdbSaveInfo *rsi) {
    int redis_bits = (sizeof(void*) == 8) ? 64 : 32;
    int aof_preamble = (flags & RDB_SAVE_AOF_PREAMBLE) != 0;

    /* Add a few fields about the state when the RDB was created. */
    if (rdbSaveAuxFieldStrStr(rdb,"redis-ver",REDIS_VERSION) == -1) return -1;
    if (rdbSaveAuxFieldStrInt(rdb,"redis-bits",redis_bits) == -1) return -1;
    if (rdbSaveAuxFieldStrInt(rdb,"ctime",time(NULL)) == -1) return -1;
    if (rdbSaveAuxFieldStrInt(rdb,"used-mem",zmalloc_used_memory()) == -1) return -1;

    /* Handle saving options that generate aux fields. */
    if (rsi) {
        if (rdbSaveAuxFieldStrInt(rdb,"repl-stream-db",rsi->repl_stream_db)
            == -1) return -1;
        if (rdbSaveAuxFieldStrStr(rdb,"repl-id",server.replid)
            == -1) return -1;
        if (rdbSaveAuxFieldStrInt(rdb,"repl-offset",server.master_repl_offset)
            == -1) return -1;
    }
    if (rdbSaveAuxFieldStrInt(rdb,"aof-preamble",aof_preamble) == -1) return -1;
    return 1;
}
```

以上可以看出会写入这些字段.

* `redis-ver`：版本号

* `redis-bits`：OS 操作系统位数 32/64

* `ctime`：RDB文件创建时间

* `used-mem`：使用内存大小

* `repl-stream-db`：在server.master客户端中选择的数据库

* `repl-id`：当前实例 replication ID

* `repl-offset`：当前实例复制的偏移量

每一个属性写入前都会写入 `0XFA`, 标记这是一个辅助字段.在上面命令行输出中,`ascii` 展示为 `372` 

### 数据库相关标记

```bash
0000050    65  c0  00  fe  00  fb  01  00  00  03  6d  73  67  05  68  65
           e 300  \0 376  \0 373 001  \0  \0 003   m   s   g 005   h   e
```

这一行中的 `0XFE` 表示选择数据库,后面紧接着 `00` 即为,选择 0 号数据库. `0XFB` 是标记了当前数据库中键存储的数量,这里用到了 `Length Encoding`, `01` 是我们存储的字典中`key-value`的数量,`00` 是过期字典(`expires`)中的数量.

> redisDB中有两个属性, `dict` 记录了我们写入的所有键, `expires` 存储了我们设置有过期时间的键以及其过期时间.

### Key Value 结构

我们设置了 `msg` -> `hello`,在输出中是这样的.

```bash
0000050    65  c0  00  fe  00  fb  01  00  00  03  6d  73  67  05  68  65
           e 300  \0 376  \0 373 001  \0  \0 003   m   s   g 005   h   e
```

在 `msg` 前面的字段 `\0 003`, 表示他是 `string` 类型, 且长度为 `3`, `005 hello`, 表示是长度为 `5` 的 `hello`.

还有其他数据结构这里就不做展示了.	

### 结束符 & 校验码

```bash
0000060    6c  6c  6f  ff  fc  0e  6b  79  fe  47  1a  36
           l   l   o 377 374 016   k   y 376   G 032   6
```

最后一行输出中 `0xff` , 文件结束符, 剩下的八个字节就是 `CRC64` 

## 参考

1. https://cloud.tencent.com/developer/article/1179710

2. [Redis5.0 RDB文件解析](https://juejin.im/post/5d8dc285f265da5b9e0d3089)