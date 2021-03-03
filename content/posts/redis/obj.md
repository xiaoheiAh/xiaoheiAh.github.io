---
title: "Redis-万物皆「对象」"
date: 2019-11-04T18:56:15+08:00
draft: false
tags: ["redis"]
categories: ["redis"]
description: "「Redis 学习笔记」| redis 对象 | object | 结构定义"
featured_image:
---

Redis有很多种数据结构,但其并没有直接使用这些数据结构来构建这个 `NOSQL`, 而是通过 `对象系统` 完成了对所有数据结构的统一管理, 实现内存回收, 对象共享等特性~

<!--more-->

## 类型及编码

在 `Redis` 中使用任何命令操作,都是操作的一个对象.有键对象,值对象.

```bash
set msg "hello~" # msg 为键对象, "hello~" 为值对象
```

每个对象都会有如下的结构:

```c
typedef struct redisObject {
    unsigned type:4; // 类型
    unsigned encoding:4; // 编码
    unsigned lru:LRU_BITS; /* LRU time (relative to global lru_clock) or
                            * LFU data (least significant 8 bits frequency
                            * and most significant 16 bits access time). */
    int refcount; // 引用计数
    void *ptr; // 指向底层实现数据结构的指针
} robj;
```

### type 类型

`type` 指明了该对象的类型. `redis` 中类型有如下几种

```c
/* The actual Redis Object */
#define OBJ_STRING 0    /* String object. */
#define OBJ_LIST 1      /* List object. */
#define OBJ_SET 2       /* Set object. */
#define OBJ_ZSET 3      /* Sorted set object. */
#define OBJ_HASH 4      /* Hash object. */
#define OBJ_MODULE 5    /* Module object. */
#define OBJ_STREAM 6    /* Stream object. */
```

`redis` 中键都为字符串对象,利用 `type` 命令可以查看值对象的类型

```bash
reids> type language
list
```

### encoding 编码

`encoding` 属性记录了该对象使用的什么数据结构存储底层的实现,即 `*ptr` 所指向的那个数据结构.以下是目前的编码类型.

```c
/* Objects encoding. Some kind of objects like Strings and Hashes can be
 * internally represented in multiple ways. The 'encoding' field of the object
 * is set to one of this fields for this object. */
#define OBJ_ENCODING_RAW 0     /* Raw representation */
#define OBJ_ENCODING_INT 1     /* Encoded as integer */
#define OBJ_ENCODING_HT 2      /* Encoded as hash table */
#define OBJ_ENCODING_ZIPMAP 3  /* Encoded as zipmap */
#define OBJ_ENCODING_ZIPLIST 5 /* Encoded as ziplist */
#define OBJ_ENCODING_INTSET 6  /* Encoded as intset */
#define OBJ_ENCODING_SKIPLIST 7  /* Encoded as skiplist */
#define OBJ_ENCODING_EMBSTR 8  /* Embedded sds string encoding */
#define OBJ_ENCODING_QUICKLIST 9 /* Encoded as linked list of ziplists */
#define OBJ_ENCODING_STREAM 10 /* Encoded as a radix tree of listpacks */
```

基本上每种类型的对象都会对应两种编码类型,可以动态的根据用户输入的值提供最有的数据结构,减少资源消耗.

## 字符串对象

字符串对象有三种编码格式. `int`,`embstr`,`raw`,不同长度不同格式有不一样的编码类型.

```bash
47.100.254.74:6379> set msg "abcdefg"
OK
(0.53s)
47.100.254.74:6379> object encoding msg
"embstr"
47.100.254.74:6379> set msg "abcdefghijklmnopqrstuvwxyz01234567890123456789"
OK
47.100.254.74:6379> object encoding msg
"raw"
47.100.254.74:6379> set msg 123
OK
47.100.254.74:6379> object encoding msg
"int"
```

### embstr vs raw

一个字符串对象包括 `redisObject` 和 `sds` 两部分组成.正常情况下是需要分配两次内存来创建这两个结构.这也是`raw` 的格式,但是如果当 `value` 长度较短时, (由于 `redis` 使用的是 [jemalloc](https://github.com/jemalloc/jemalloc)  分配内存)我们可以将内存分配控制在一次,将 `RedisObject` 和 `sds` 分配在连续的内存空间,这也就是 `embstr` 编码格式了.那多短算短呢?

 在此之前先了解下创建一个 `redisObject` 时所占用的空间. 

![redis-obj-malloc](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191105112554.png)

`embstr`编码是由 代表着 字符串的数据结构是 `SDS`.假设为 `sdshdr8`

```c
struct sdshdr8 {
    uint8_t len; /* 1byte used */
    uint8_t alloc; /* 1byte excluding the header and null terminator */
    unsigned char flags; /* 1byte 3 lsb of type, 5 unused bits */
    char buf[];
};
```

`jemalloc` 可以分配 8/16/32/64 字节大小的内存,从上可以发现最少的内存需要占用 19 字节, Redis 在总体大于 64 字节时,会改为 `raw` 存储. 所以 `embstr` 形式时最大长度是 `64 - 19 - 结束符\0长度 = 44`

![embstr](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191105121309.png)

### 编码转换

由于 `redis` 没有为 `embstr` 编写修改相关的程序,所以是只读的, 如果对其执行任何修改命令,就会变为 `raw` 格式.

## 类型检查

`redis` 中的操作命令一般有两种: 所有类型都能用的(`DEL`, `EXPIRE`...), 特定类型适用的(各种数据类型对应的命令).若操作键的命令不对, `redis` 会提示报错.

```bash
47.100.254.74:6379> set numbers 1
OK
47.100.254.74:6379> object encoding numbers
"int"
47.100.254.74:6379> rpush numbers a
(error) WRONGTYPE Operation against a key holding the wrong kind of value
```

### 如何实现?

利用 `RedisObject` 的`type` 来控制.在输入一个命令时, 服务器会先检查输入键所对应的的值对象是否为命令对应的类型,是的话就执行,不是就报错.

## 多态命令

同一种数据结构可能有多种编码格式.比如字符串对象的编码格式可能有 `int`, `embstr`, `raw`.所以当命令执行前,还需要根据值对象的编码来选择正确的命令来实现.

比如想要执行 `llen` 获取 list 长度, 如果编码为 `ziplist`, 那么程序就会使用 `ziplist` 对应的函数来计算, 编码为 `quicklist` 时则是使用 `quicklist` 对应的函数来计算. 此为命令的 **多态** .

## 内存回收

`redis` 利用引用计数来实现内存回收机制.由 `RedisObject` 中的 `refcount` 属性记录.

引用计数是有导致循环引用的弊端的,那么redis为啥还是会用的?找了很久也没有找到答案.

有一个说法是: 引用的复杂度很低,不太容易导致循环引用.就一切从简呗.

## 对象共享

对象共享指的是创建一次对象后,后面如果还有客户端需要创建同样的值对象则直接把现在这个的引用只给他,引用计数加1,可以节省内存的开销.类似 Java 常量池. 所以`refcount` 也被用来做对象共享的.

`redis` 在初始化服务器时, 会创建 0 - 9999 一万个整数字符串, 为了节省资源.

### 为什么不共享其他的复杂对象?

1. 整数复用几率很大
2. 整数比较算法时间复杂度是 O(1), 字符串是 O(N), hash/list 复杂度是 O(n2)

## 键的空转时长

`redisObject` 的 `lru` 属性记录着该对象最后一次被命令程序访问的时间.该属性在内存回收中有很大的作用.

空转时长指的是` now() - lru`

```bash
47.100.254.74:6379> object idletime numbers
(integer) 4023
```







