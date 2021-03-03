---
title: "[学习笔记] Netty"
date: 2019-11-29T18:40:27+08:00
draft: false
tags: ["netty"]
categories: ["学习笔记"]
description: "「Netty 学习笔记」"
featured_image: 
---

<!--more-->

> Netty 是一个异步事件驱动的网络应用框架，用于快速开发可维护的高性能服务器和客户端。

**NIO:** selector 模型,用一个线程监听多个连接的读写请求,减少线程资源的浪费.

### netty 优点

1. 使用 JDK 自带的NIO需要了解太多的概念，编程复杂，一不小心 bug 横飞
2. Netty 底层 IO 模型随意切换，而这一切只需要做微小的改动，改改参数，Netty可以直接从 NIO 模型变身为 IO 模型
3. Netty 自带的拆包解包，异常检测等机制让你从NIO的繁重细节中脱离出来，让你只需要关心业务逻辑
4. Netty 解决了 JDK 的很多包括空轮询在内的 Bug
5. Netty 底层对线程，selector 做了很多细小的优化，精心设计的 reactor 线程模型做到非常高效的并发处理
6. 自带各种协议栈让你处理任何一种通用协议都几乎不用亲自动手
7. Netty 社区活跃，遇到问题随时邮件列表或者 issue
8. Netty 已经历各大 RPC 框架，消息中间件，分布式通信中间件线上的广泛验证，健壮性无比强大

### Server端

```java
// 负责服务端的启动
ServerBootstrap serverBootstrap = new ServerBootstrap();
// 负责接收新连接
NioEventLoopGroup boss = new NioEventLoopGroup();
// 负责读取数据及业务逻辑处理
NioEventLoopGroup worker = new NioEventLoopGroup();

serverBootstrap.group(boss, worker)
  // 指定服务端 IO 模型为 NIO
  .channel(NioServerSocketChannel.class)
  // 业务逻辑处理
  .childHandler(new ChannelInitializer<NioSocketChannel>() {
    protected void initChannel(NioSocketChannel ch) throws Exception {
      ch.pipeline().addLast(new StringDecoder());
      ch.pipeline().addLast(new SimpleChannelInboundHandler<String>() {
        protected void channelRead0(ChannelHandlerContext channelHandlerContext, String s) throws Exception {
          System.out.println(s);
        }
      });
    }
  })
  .bind(8000);
```

* **NioSocketChannel/NioServerSocketChannel** Netty 对 NIO 类型连接的抽象

#### handler() & childHandler()

* handler() 用于指定服务器端在启动过程中的一些逻辑
* childHandler() 用于指定处理新连接数据的读写逻辑

#### attr() & childAttr()

分别可以给服务端连接,客户端连接指定相应的属性,后续通过 `channel.attr()` 可以拿到.

#### option() & childOption()

* option() 用于给服务端连接设定一系列的属性,最常见的是 `so_backlog`

  ```java
  // 表示系统用于临时存放已完成三次握手的请求的队列的最大长度，如果连接建立频繁，服务器处理创建新连接较慢，可以适当调大这个参数
  serverBootstrap.option(ChannelOption.SO_BACKLOG, 1024)
  ```

* childOption() 给每条连接设置一些属性

  ```java
  serverBootstrap
    			// 是否开启TCP底层心跳机制，true为开启
          .childOption(ChannelOption.SO_KEEPALIVE, true)
    			// 是否开启Nagle算法，true表示关闭，false表示开启，通俗地说，如果要求高实时性，有数据发送时就马上发送，就关闭，如果需要减少发送次数减少网络交互，就开启。
          .childOption(ChannelOption.TCP_NODELAY, true)
  ```

### Client端

带连接失败重试的客户端,失败重试延迟为 2 的幂次.

```java
// 客户端启动
Bootstrap bootstrap = new Bootstrap();
// 线程模型
NioEventLoopGroup group = new NioEventLoopGroup();

bootstrap.group(group)
  // 指定 IO 模型为 NIO
  .channel(NioSocketChannel.class)
  // 业务逻辑处理
  .handler(new ChannelInitializer<Channel>() {
    protected void initChannel(Channel ch) throws Exception {
      ch.pipeline().addLast(new StringEncoder());
    }
  });
connect(bootstrap,"127.0.0.1", 8000, MAX_RETRY);

private static void connect(Bootstrap bootstrap, String host, int port, int retry) {
    bootstrap.connect(host, port).addListener(future -> {
        if (future.isSuccess()) {
            System.out.println("连接成功!");
        } else if (retry == 0) {
            System.err.println("重试次数已用完，放弃连接！");
        } else {
            // 第几次重连
            int order = (MAX_RETRY - retry) + 1;
            // 本次重连的间隔
            int delay = 1 << order;
            System.err.println(new Date() + ": 连接失败，第" + order + "次重连……");
            bootstrap.config().group().schedule(() -> connect(bootstrap, host, port, retry - 1), delay, TimeUnit
                    .SECONDS);
        }
    });
}
```

#### 其他方法

* attr() 客户端绑定属性
* option() 设置客户端 TCP 连接

### ByteBuf

netty 中的数据都是以 `ByteBuf` 为单位的,所有需要写出的数据都必须塞到 `ByteBuf` 中.

![ByteBuf-数据结构(掘金小册配图)](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191202111539.png)

1. `ByteBuf` 是一个字节容器，容器里面的的数据分为三个部分，第一个部分是已经丢弃的字节，这部分数据是无效的；第二部分是可读字节，这部分数据是 `ByteBuf` 的主体数据， 从 `ByteBuf` 里面读取的数据都来自这一部分;最后一部分的数据是可写字节，所有写到 `ByteBuf` 的数据都会写到这一段。最后一部分虚线表示的是该 `ByteBuf` 最多还能扩容多少容量
2. 以上三段内容是被两个指针给划分出来的，从左到右，依次是读指针（`readerIndex`）、写指针（`writerIndex`），然后还有一个变量 `capacity`，表示 `ByteBuf` 底层内存的总容量
3. 从 ByteBuf 中每读取一个字节，`readerIndex` 自增1，`ByteBuf` 里面总共有 `writerIndex-readerIndex` 个字节可读, 由此可以推论出当 `readerIndex` 与 `writerIndex` 相等的时候，`ByteBuf` 不可读
4. 写数据是从 `writerIndex` 指向的部分开始写，每写一个字节，`writerIndex` 自增1，直到增到 `capacity`，这个时候，表示 `ByteBuf` 已经不可写了
5. `ByteBuf` 里面其实还有一个参数 `maxCapacity`，当向 `ByteBuf` 写数据的时候，如果容量不足，那么这个时候可以进行扩容，直到 `capacity` 扩容到 `maxCapacity`，超过 `maxCapacity` 就会报错

#### ByteBuf 容量相关API

##### capacity()

表示 ByteBuf 底层占用了多少字节的内存（包括丢弃的字节、可读字节、可写字节），不同的底层实现机制有不同的计算方式，后面我们讲 ByteBuf 的分类的时候会讲到

##### maxCapacity()

表示 ByteBuf 底层最大能够占用多少字节的内存，当向 ByteBuf 中写数据的时候，如果发现容量不足，则进行扩容，直到扩容到 maxCapacity，超过这个数，就抛异常

##### readableBytes() 与 isReadable()

readableBytes() 表示 ByteBuf 当前可读的字节数，它的值等于 writerIndex-readerIndex，如果两者相等，则不可读，isReadable() 方法返回 false

##### writableBytes()、 isWritable() 与 maxWritableBytes()

writableBytes() 表示 ByteBuf 当前可写的字节数，它的值等于 capacity-writerIndex，如果两者相等，则表示不可写，isWritable() 返回 false，但是这个时候，并不代表不能往 ByteBuf 中写数据了， 如果发现往 ByteBuf 中写数据写不进去的话，Netty 会自动扩容 ByteBuf，直到扩容到底层的内存大小为 maxCapacity，而 maxWritableBytes() 就表示可写的最大字节数，它的值等于 maxCapacity-writerIndex

#### ByteBuf 读写指针相关 API

##### readerIndex() 与 readerIndex(int)

前者表示返回当前的读指针 readerIndex, 后者表示设置读指针

##### writeIndex() 与 writeIndex(int)

前者表示返回当前的写指针 writerIndex, 后者表示设置写指针

##### markReaderIndex() 与 resetReaderIndex()

前者表示把当前的读指针保存起来，后者表示把当前的读指针恢复到之前保存的值

##### markWriterIndex() 与 resetWriterIndex()

同上,但是针对写指针

#### ByteBuf 读写 API

##### writeBytes(byte[] src) 与 buffer.readBytes(byte[] dst)

writeBytes() 表示把字节数组 src 里面的数据全部写到 ByteBuf，而 readBytes() 指的是把 ByteBuf 里面的数据全部读取到 dst，这里 dst 字节数组的大小通常等于 readableBytes()，而 src 字节数组大小的长度通常小于等于 writableBytes()

##### writeByte(byte b) 与 buffer.readByte()

writeByte() 表示往 ByteBuf 中写一个字节，而 buffer.readByte() 表示从 ByteBuf 中读取一个字节，类似的 API 还有 writeBoolean()、writeChar()、writeShort()、writeInt()、writeLong()、writeFloat()、writeDouble() 与 readBoolean()、readChar()、readShort()、readInt()、readLong()、readFloat()、readDouble() 

与读写 API 类似的 API 还有 getBytes、getByte() 与 setBytes()、setByte() 系列，唯一的区别就是 get/set 不会改变读写指针，而 read/write 会改变读写指针，这点在解析数据的时候千万要注意

##### release() 与 retain()

由于 Netty 使用了 **堆外内存**，而堆外内存是不被 jvm 直接管理的，也就是说申请到的内存无法被垃圾回收器直接回收，所以需要我们**手动回收**。有点类似于c语言里面，申请到的内存必须手工释放，否则会造成内存泄漏。

Netty 的 ByteBuf 是通过引用计数的方式管理的，如果一个 ByteBuf 没有地方被引用到，需要回收底层内存。默认情况下，当创建完一个 ByteBuf，它的引用为1，然后每次调用 retain() 方法， 它的引用就加一， release() 方法原理是将引用计数减一，减完之后如果发现引用计数为0，则直接回收 ByteBuf 底层的内存。

##### slice()、duplicate()、copy()

这三个方法通常情况会放到一起比较，这三者的返回值都是一个新的 ByteBuf 对象

1. slice() 方法从原始 ByteBuf 中截取一段，这段数据是从 readerIndex 到 writeIndex，同时，返回的新的 ByteBuf 的最大容量 maxCapacity 为原始 ByteBuf 的 readableBytes()
2. duplicate() 方法把整个 ByteBuf 都截取出来，包括所有的数据，指针信息
3. slice() 方法与 duplicate() 方法的相同点是：**底层内存以及引用计数与原始的 ByteBuf 共享**，也就是说经过 slice() 或者 duplicate() 返回的 ByteBuf 调用 write 系列方法都会影响到 原始的 ByteBuf，但是它们都维持着与原始 ByteBuf 相同的内存引用计数和不同的读写指针
4. slice() 方法与 duplicate() 不同点就是：slice() 只截取从 readerIndex 到 writerIndex 之间的数据，它返回的 ByteBuf 的最大容量被限制到 原始 ByteBuf 的 readableBytes(), 而 duplicate() 是把整个 ByteBuf 都与原始的 ByteBuf 共享
5. slice() 方法与 duplicate() 方法不会拷贝数据，它们只是通过改变读写指针来改变读写的行为，而最后一个方法 copy() 会直接从原始的 ByteBuf 中拷贝所有的信息，包括读写指针以及底层对应的数据，因此，**往 copy() 返回的 ByteBuf 中写数据不会影响到原始的 ByteBuf**
6. slice() 和 duplicate() 不会改变 ByteBuf 的引用计数，所以原始的 ByteBuf 调用 release() 之后发现引用计数为零，就开始释放内存，调用这两个方法返回的 ByteBuf 也会被释放，这个时候如果再对它们进行读写，就会报错。因此，我们可以通过调用一次 retain() 方法 来增加引用，表示它们对应的底层的内存多了一次引用，引用计数为2，在释放内存的时候，需要调用两次 release() 方法，将引用计数降到零，才会释放内存
7. 这三个方法均维护着自己的读写指针，与原始的 ByteBuf 的读写指针无关，相互之间不受影响

### Pipeline & ChannelHandler

`pipeline` 的数据结构为 双向链表, 节点的类型是一个 `ChannelHandlerContext` 包含着 每一个 `channel` 的上下文信息, `contenxt` 中包裹着一个 `handler` 用于处理用户的逻辑,`pipeline` 利用 **责任链** 的模式执行完所有的 `handler`.

![掘金小册-pipeline构成](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191202194426.png)

#### 内置的 ChannelHandler

1. **ByteToMessageDecoder**

   二进制 -> Java 对象转换,重写 `decode` 方法即可.默认情况下 `ByteBuf` 使用的是对外内存,通过引用计数判断是否需要清除.而该 `Decoder` 可以自动释放内存无需关心.

2. **SimpleChannelInboundHandler**

   自动选择对应的消息进行处理,自动传递对象

3. **MessageToByteEncoder**

   对象 -> 二进制

### 粘包 & 拆包

> https://www.cnblogs.com/wade-luffy/p/6165671.html

TCP 的传输是基于字节流的,没有明显的分界,有可能会把应用层的多个包合在一块发出去(**粘包**),有可能把一个过大的包分多次发出(**拆包**),粘包/拆包是相对的,一方拆包,一方就要粘包.

#### TCP粘包/拆包发生的原因

问题产生的原因有三个，分别如下。

（1）应用程序write写入的字节大小大于套接口发送缓冲区大小；

（2）进行MSS大小的TCP分段；

（3）以太网帧的payload大于MTU进行IP分片。

#### 解决策略

通过应用层设计通用的结构保证.

1. 消息定长，例如每个报文的大小为固定长度200字节，如果不够，空位补空格；
2. 在包尾增加回车换行符进行分割，例如FTP协议；
3. 将消息分为消息头和消息体，消息头中包含表示消息总长度（或者消息体长度）的字段，通常设计思路为消息头的第一个字段使用int32来表示消息的总长度；
4. 更复杂的应用层协议

#### netty 解决方案

netty 提供了多种拆包器,满足用户的需求,不需要自己来对 `TCP` 流进行处理.

1. 固定长度拆包器 **FixedLengthFrameDecoder**

2. 行拆包器 **LineBasedFrameDecoder**

   数据包以换行符作为分隔.

3. 分隔符拆包器 **DelimiterBasedFrameDecoder**

   行拆包器的通用版,自定义分隔符

4. 基于长度域拆包器 **LengthFieldBasedFrameDecoder**

   自定义的协议中包含长度域字段,即可使用来拆包

   > 每次的包不是定长的,怎么就能通过位移确认长度域,进而确定长度?
   >
   > 答: 通过设置一个完整包的开始标志,确定是一个新包就可以了.比如通常会设置一个魔数,拆包前先判断是不是我们定义的包.然后再去通过位移定位到长度域.

   

### ChannelHandler 生命周期

![生命周期图](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191203165854.png)

1. `handlerAdded()` ：指的是当检测到新连接之后，调用 `ch.pipeline().addLast(new xxxHandler());` 之后的回调，表示在当前的 channel 中，已经成功添加了一个 handler 处理器。
2. `channelRegistered()`：这个回调方法，表示当前的 channel 的所有的逻辑处理已经和某个 NIO 线程建立了绑定关系，accept 到新的连接，然后创建一个线程来处理这条连接的读写，Netty 里面是使用了线程池的方式，只需要从线程池里面去抓一个线程绑定在这个 channel 上即可，这里的 NIO 线程通常指的是 `NioEventLoop`,不理解没关系，后面我们还会讲到。
3. `channelActive()`：当 channel 的所有的业务逻辑链准备完毕（也就是说 channel 的 pipeline 中已经添加完所有的 handler）以及绑定好一个 NIO 线程之后，这条连接算是真正激活了，接下来就会回调到此方法。
4. `channelRead()`：客户端向服务端发来数据，每次都会回调此方法，表示有数据可读。
5. `channelReadComplete()`：服务端每次读完一次完整的数据之后，回调该方法，表示数据读取完毕。
6. `channelInactive()`: 表面这条连接已经被关闭了，这条连接在 TCP 层面已经不再是 **ESTABLISH** 状态了
7. `channelUnregistered()`: 既然连接已经被关闭，那么与这条连接绑定的线程就不需要对这条连接负责了，这个回调就表明与这条连接对应的 NIO 线程移除掉对这条连接的处理
8. `handlerRemoved()`：最后，我们给这条连接上添加的所有的业务逻辑处理器都给移除掉。

### 心跳 & 空闲检测

#### IdleStateHandler

空闲检测(一段时间内是否有读写).

#### 实现一个心跳

```java
public class HeartBeatTimerHandler extends ChannelInboundHandlerAdapter {

    private static final int HEARTBEAT_INTERVAL = 5;

    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        scheduleSendHeartBeat(ctx);

        super.channelActive(ctx);
    }

    private void scheduleSendHeartBeat(ChannelHandlerContext ctx) {
        ctx.executor().schedule(() -> {

            if (ctx.channel().isActive()) {
                ctx.writeAndFlush(new HeartBeatRequestPacket());
                scheduleSendHeartBeat(ctx);
            }

        }, HEARTBEAT_INTERVAL, TimeUnit.SECONDS);
    }
}
```



### 性能优化方案


1. 共享 handler  `@ChannelHandler.Sharable`
2. 压缩 handler - 合并编解码器 —— MessageToMessageCodec
3. 虽然有状态的 handler 不能搞单例，但是你可以绑定到 channel 属性上，强行单例
4. 缩短事件传播路径—— 放 Map 里，在第一个 handler 里根据指令来找具体 handler。
5. 更改事件传播源—— 用 ctx.writeAndFlush() 不要用 ctx.channel().writeAndFlush()
6. 减少阻塞主线程的操作—— 使用业务线程池，RPC 优化重点
7. 计算耗时，使用回调 Future
