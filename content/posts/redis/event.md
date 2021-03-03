---
title: "Redis-事件"
date: 2019-11-14T15:01:45+08:00
draft: false
tags: ["redis"]
categories: ["redis"]
description: "「Redis 学习笔记」| 事件驱动 | event | 多路复用"
featured_image:
---

> **事件驱动程序设计**（英语：**Event-driven programming**）是一种电脑[程序设计](https://zh.wikipedia.org/wiki/程式設計)[模型](https://zh.wikipedia.org/wiki/模型)。这种模型的程序运行流程是由用户的动作（如[鼠标](https://zh.wikipedia.org/wiki/滑鼠)的按键，键盘的按键动作）或者是由其他程序的[消息](https://zh.wikipedia.org/wiki/訊息)来决定的。相对于批处理程序设计（batch programming）而言，程序运行的流程是由[程序员](https://zh.wikipedia.org/wiki/程式設計師)来决定。批量的程序设计在初级程序设计教学课程上是一种方式。然而，事件驱动程序设计这种设计模型是在[交互程序](https://zh.wikipedia.org/w/index.php?title=互動程序&action=edit&redlink=1)（Interactive program）的情况下孕育而生的。	[--wikipedia](https://zh.wikipedia.org/wiki/事件驅動程式設計)

<!--more-->

## 文件事件

服务端通过套接字与客户端进行连接,文件事件就是服务端对套接字操作的抽象.服务端与客户端的通信会产生多种文件事件(连接 `accept` ,读取 `read`, 写入 `write` ,关闭 `close`),服务器监听并处理相应的事件.

### 文件事件处理器

`redis` 基于 `Reactor` 模式实现了网络事件处理 --> **文件时间处理器**.通过 `I/O 多路复用` 保证了单进程下的高性能网络模型.

#### 什么是 I/O Multiplexing?   

参考: https://draveness.me/redis-io-multiplexing

首先需要知道什么是文件描述符(`File Descriptor` ,简称 `FD`)? 文件描述符就是操作系统中操作文件时内核返回的一个 **非负整数**,可以通过文件描述符来指定待读写的文件.而套接字 `socket` 本质上也是一种文件描述符.

简单来说就是通常我们使用的 `I/O` 模型是阻塞型的,服务器在处理一个客户端请求(即处理一个`FD`)时无法再处理其它的了. `I/O多路复用` 是通过利用操作系统的多路复用函数(`select()`)来监听多个 `FD` 的可读可写情况,一旦有可读或可写的 `FD`,`select()` 就返回对应的个数.

<img src="https://img.draveness.me/2016-11-26-redis-choose-io-function.jpg-1000width" alt="盗用draveness大佬的图-侵删" style="zoom:50%;" />

由于不同操作系统的有不同的多路复用函数,`select`是性能最差的.而 `redis` 也会根据操作系统的不同选择性能最好的函数来使用.并且由于不同平台的差异, `redis` 提供了一套相同的结构并针对不同平台进行了实现,以此屏蔽了对上层应用的影响.

```c
#ifdef HAVE_EVPORT
#include "ae_evport.c"
#else
    #ifdef HAVE_EPOLL
    #include "ae_epoll.c"
    #else
        #ifdef HAVE_KQUEUE
        #include "ae_kqueue.c"
        #else
        #include "ae_select.c"
        #endif
    #endif
#endif
```

#### 文件事件处理器结构

<img src="https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191115142151.png" alt="文件事件处理器结构" style="zoom:50%;" />

每一个套接字 `socket` 可以执行连接,读写,关闭操作时,会产生一个 **文件事件**.,`I/O 多路复用` 监听这些 `FD` 的操作请求,并向 **文件事件派发器** 传递产生文件事件的 `FD`. 虽然会并发的产生 N 个文件事件,但 `I/O多路复用` 会将其都放入一个队列中,**顺序且同步地**向 **文件事件分派器** 传送.处理完一个再传下一个.

**文件事件派发器** 接收到 `FD` 后,就会根据`FD` 所绑定的文件事件类型选择相应的事件处理器进行处理.

#### 文件事件类型

* **AE_READABLE** 可读事件

  客户端对套接字 `write` 操作, `close` 操作或者客户端与服务端进行连接(出现 `acceptable` 套接字)时产生可读事件

* **AE_WRITABLE** 可写事件

  客户端对套接字执行 `read` 操作,套接字产生可写事件

* **AE_NONE** 无任何事件

##### 事件处理的先后顺序

**AE_READABLE** > **AE_WRITABLE**

### 事件处理器

事件处理器是针对不同的文件事件实现的逻辑.客户端连接时,服务器需要进行应答,此时服务器就会将套接字关联到应答处理器.接收客户端的命令请求,服务器会将套接字关联到命令请求处理器.

#### 常用时间处理器

1. 连接应答处理器 `networking.c/acceptTcpHandler`

   客户端连接时会对其进应答.`redis` 在初始化时会将服务器的监听套接字的可读事件与该处理器关联起来,客户端只要连接监听套接字就会产生可读事件,执行对应的逻辑.

2. 命令请求处理器 `networking.c/readQueryFromClient`

   客户端连接服务器后,服务器会将客户端套接字的可读事件与命令请求处理器关联起来,当客户端向服务器发送命令请求时,产生可读事件,执行对应逻辑.

3. 命令回复处理器 `networking.c/sendReplyToClient`

   服务器有命令回复需要传送给客户端时,服务器会将客户端套接字的可写事件与命令回复处理器关联起来,客户端准备好接收服务器回复时,会产生可写事件,触发命令回复器执行.服务器发送完毕时,会解除关联.

### 文件事件处理流程

<img src="https://img.draveness.me/2016-12-09-eventloop-file-event-in-redis.png-1000width" alt="draveness.me-侵删" style="zoom:50%;" />

`aeCreateFileEvent` 可以将一个给定`FD` 的给定事件加入到多路复用的监听范围中,并将事件与时间处理器关联

`aeDeleteFileEvent` 取消给定`FD` 的给定事件的监听

`aeApiPoll` 该方法会在每个平台的多路复用中进行实现,阻塞等待所有监听的`FD` 所产生的事件并返回可用时间的数量.会有超时处理.



## 时间事件

`Redis` 中有两种时间事件 ---- 定时事件(隔一段时间执行一次),非定时事件(某个时间点执行一次)

### 属性

1. **id** 全局唯一ID,顺序递增
2. **when** 毫秒精度 UNIX 时间戳,记录时间事件到达时间
3. **timeProc** 时间事件处理器,需要执行时间事件时,根据该处理器执行

时间事件是定时还是非定时,取决去 `timeProc` 返回值是否等于 `AE_NOMORE`. 等于则给事件ID标记为待删除,不等于则更新执行时间到下一次.

```c
retval = te->timeProc(eventLoop, id, te->clientData);
if (retval != AE_NOMORE) {
  aeAddMillisecondsToNow(retval,&te->when_sec,&te->when_ms);
} else {
  te->id = AE_DELETED_EVENT_ID;
}
```
`Redis` 处理时间事件时，不会在当前循环中直接移除不再需要执行的事件，而是会在当前循环中将时间事件的 `id` 设置为 `AE_DELETED_EVENT_ID`，然后再下一个循环中删除，并执行绑定的 `finalizerProc`。

```c
/* Remove events scheduled for deletion. */
if (te->id == AE_DELETED_EVENT_ID) {
  aeTimeEvent *next = te->next;
  if (te->prev)
    te->prev->next = te->next;
  else
    eventLoop->timeEventHead = te->next;
  if (te->next)
    te->next->prev = te->prev;
  if (te->finalizerProc)
    te->finalizerProc(eventLoop, te->clientData);
  zfree(te);
  te = next;
  continue;
}	
```
### 时钟问题

时间事件的执行影响最大的因素就是 **系统时间**. 系统时间的调整会影响时间事件的执行,所以在`eventLoop` 中有个 `lastTime` 属性来检测系统时间.如果发现系统时间改变了,比上次执行时间事件的时间小,就会强制尽早执行.

#### 时间事件执行流程

<img src="https://img.draveness.me/2016-12-09-process-time-event.png-1000width" alt="draveness.me-侵删" style="zoom:50%;" />

## 事件循环 Event Loop

上述的 `文件事件`, `时间事件` 是从何时开始? 在 `事件循环` 中开始. `事件循环` 是 `redis` 在启动后初始化完服务配置,就会陷入一个巨大的循环 `aeEventLoop` 中. 这个巨大的循环从 `aeMain()` 开始.

```c
void aeMain(aeEventLoop *eventLoop) {
    eventLoop->stop = 0;
    while (!eventLoop->stop) {
        if (eventLoop->beforesleep != NULL)
            eventLoop->beforesleep(eventLoop);
        aeProcessEvents(eventLoop, AE_ALL_EVENTS|AE_CALL_AFTER_SLEEP);
    }
}
```

源码中可以看出来,除非给 `eventLoop->stop` 设置为 `true` ,程序会一直跑,一直执行 `aeProcessEvents`.

### aeEventLoop

![draveness.me-aeEventLoop 结构](https://img.draveness.me/2016-12-09-reids-eventloop.png-1000width)

`aeEventLoop` 保存着事件循环的上下文信息,并有三个重要的数组:保存监听的文件事件 `aeFileEvent` , 时间事件 `aeTimeEvent`, 待处理文件事件 `aeFiredEvent`.

### aeProcessEvent

在一般情况下，`aeProcessEvents` 都会先**计算最近的时间事件发生所需要等待的时间**，然后调用 `aeApiPoll` 方法在这段时间中等待事件的发生，在这段时间中如果发生了文件事件，就会优先处理文件事件，否则就会一直等待，直到最近的时间事件需要触发.

```c
int aeProcessEvents(aeEventLoop *eventLoop, int flags) {
    int processed = 0, numevents;

    if (!(flags & AE_TIME_EVENTS) && !(flags & AE_FILE_EVENTS)) return 0;

    if (eventLoop->maxfd != -1 ||
        ((flags & AE_TIME_EVENTS) && !(flags & AE_DONT_WAIT))) {
        struct timeval *tvp;

        #1：计算 I/O 多路复用的等待时间 tvp

        numevents = aeApiPoll(eventLoop, tvp);
        for (int j = 0; j < numevents; j++) {
            aeFileEvent *fe = &eventLoop->events[eventLoop->fired[j].fd];
            int mask = eventLoop->fired[j].mask;
            int fd = eventLoop->fired[j].fd;
            int rfired = 0;

            if (fe->mask & mask & AE_READABLE) {
                rfired = 1;
                fe->rfileProc(eventLoop,fd,fe->clientData,mask);
            }
            if (fe->mask & mask & AE_WRITABLE) {
                if (!rfired || fe->wfileProc != fe->rfileProc)
                    fe->wfileProc(eventLoop,fd,fe->clientData,mask);
            }
            processed++;
        }
    }
    if (flags & AE_TIME_EVENTS) processed += processTimeEvents(eventLoop);
    return processed;
}
```

## 参考

1. https://draveness.me/redis-eventloop
2. https://draveness.me/redis-io-multiplexing
3. [Redis设计与实现](https://book.douban.com/subject/25900156/)