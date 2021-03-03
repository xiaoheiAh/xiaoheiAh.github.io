---
title: "Hystrix命令执行流程"
date: 2019-08-26T15:25:08+08:00
draft: false
tags : ["rxjava","hystrix"]
description: "「RxJava」| Hystrix | 响应式编程"
keywords: ["学习笔记","Hystrix","Java","RxJava","响应式编程"]
categories: ["Hystrix"]
---

<!--more-->

## 前言

Hystrix已经不在维护了,但是成功的开源项目总是值得学习的.刚开始看 Hystrix 源码时,会发现一堆 Action,Function 的逻辑,这其实就是 RxJava 的特点了--**响应式编程**.上篇文章已经对RxJava作过[入门介绍](/2019/rxjava-guide/),不熟悉的同学可以先去看看.本文会简单介绍 Hystrix,再根据demo结合源码来了解Hystrix的执行流程.

## Hystrix简单介绍

1. 什么是 Hystrix?

     Hystrix 是一个**延迟**和**容错库**，旨在隔离对远程系统、服务和第三方库的访问点，停止级联故障，并在错误不可避免的复杂分布式系统中能够弹性恢复。

2. 核心概念

   1. **Command** 命令

        **Command** 是Hystrix的入口,对用户来说,我们只需要创建对应的 command,将需要保护的接口包装起来就可以.可以无需关注再之后的逻辑.与 Spring 深度集成后还可以通过注解的方式,就更加对开发友好了.

   2. **Circuit Breaker** 断路器

        **断路器**,是从电气领域引申过来的概念,具有**过载**、**短路**和**欠电压保护**功能，有保护线路和电源的能力.在Hystrix中即为当请求超过一定比例响应失败时,hystrix 会对请求进行拦截处理,保证服务的稳定性,以及防止出现服务之间级联雪崩的可能性.

   3. **Isolation** 隔离策略

        隔离策略是 Hystrix 的设计亮点所在,利用[舱壁模式](https://docs.microsoft.com/en-us/azure/architecture/patterns/bulkhead)的思想来对访问的资源进行隔离,每个资源是独立的依赖,单个资源的异常不应该影响到其他. Hystrix 的隔离策略目前有两种:**线程池隔离**,**信号量隔离**.

      ![isolation](https://github.com/Netflix/Hystrix/wiki/images/soa-5-isolation-focused-640.png)

3. Hystrix的运行流程

   > 官方的 [How it Works](https://github.com/Netflix/Hystrix/wiki/How-it-Works) 对流程有很详细的介绍,图示清晰,相信看完流程图就能对运行流程有一定的了解.

   ![来自hystrix的github站点](https://raw.githubusercontent.com/wiki/Netflix/Hystrix/images/hystrix-command-flow-chart.png)
## 一次Command执行

`HystrixCommand`是标准的[命令模式](https://design-patterns.readthedocs.io/zh_CN/latest/behavioral_patterns/command.html)实现,每一次请求即为一次命令的创建执行经历的过程.从上述[Hystrix流程图](#Hystrix简单介绍)可以看出创建流程最终会指向`toObservable`,在之前[RxJava入门](/2019/rxjava-guide/)时有介绍到`Observable`即为被观察者,作用是发送数据给观察者进行相应的,因此可以知道这个方法应该是较为关键的.

### UML

![hystrixcommman-uml.png](https://i.loli.net/2019/08/29/gVF4dlR6tivBcT8.png)

1. HystrixInvokable 标记这个一个可执行的接口,没有任何抽象方法或常量
2. HystrixExecutable 是为`HystrixCommand`设计的接口,主要提供执行命令的抽象方法,例如:`execute()`,`queue()`,`observe()`
3. HystrixObservable 是为`Observable`设计的接口,主要提供自动订阅(`observe()`)和生成Observable(`toObservable()`)的抽象方法
4. HystrixInvokableInfo 提供大量的状态查询(获取属性配置,是否开启断路器等)
5. AbstractCommand **核心逻辑**的实现
6. HystrixCommand 定制逻辑实现以及留给用户实现的接口(比如:`run()`)

### 样例代码

通过新建一个 command 来看 Hystrix 是如何创建并执行的.HystrixCommand 是一个抽象类,其中有一个`run`方法需要我们实现自己的业务逻辑,以下是偷懒采用匿名内部类的形式呈现.构造方法的内部实现我们就不关注了,直接看下执行的逻辑吧.

```java
HystrixCommand demo = new HystrixCommand<String>(HystrixCommandGroupKey.Factory.asKey("demo-group")) {
            @Override
            protected String run() {
                return "Hello World~";
            }
        };
demo.execute();
```

### 执行过程

#### 流程图

![execute](https://raw.githubusercontent.com/wiki/Netflix/Hystrix/images/hystrix-return-flow.png)

这是官方给出的一次完整调用的链路.上述的 demo 中我们直接调用了`execute`方法,所以调用的路径为`execute() -> queue() -> toObservable() -> toBlocking() -> toFuture() -> get()`.核心的逻辑其实就在`toObservable()`中.

#### HystrixCommand.java

##### execute

`execute`方法为同步调用返回结果,并对异常作处理.内部会调用`queue`

```java
// 同步调用执行
public R execute() {
  try {
    // queue()返回的是Future类型的对象,所以这里是阻塞get
    return queue().get();
  } catch (Exception e) {
    throw decomposeException(e);
  }
}
```

##### queue

`queue`的第一行代码完成了核心的订阅逻辑.

1. `toObservable()` 生成了 Hystrix 的 Observable 对象
2. 将 `Observable` 转换为 `BlockingObservable` 可以阻塞控制数据发送
3. `toFuture` 实现对 `BlockingObservable` 的订阅

```java
public Future<R> queue() {
  // 着重关注的是这行代码
  // 完成了Observable的创建及订阅
  // toBlocking()是将Observable转为BlockingObservable,转换后的Observable可以阻塞数据的发送
  final Future<R> delegate = toObservable().toBlocking().toFuture();

  final Future<R> f = new Future<R>() {
    // 由于toObservable().toBlocking().toFuture()返回的Future如果中断了,
    // 不会对当前线程进行中断,所以这里将返回的Future进行了再次包装,处理异常逻辑
    ...
  }

  // 判断是否已经结束了,有异常则直接抛出
  if (f.isDone()) {
    try {
      f.get();
      return f;
    } catch (Exception e) {
			// 省略这段判断
    }
  }

  return f;
}
```

#### BlockingObservable.java

```java
// 被包装的Observable
private final Observable<? extends T> o;

// toBlocking()会调用该静态方法将 源Observable简单包装成BlockingObservable
public static <T> BlockingObservable<T> from(final Observable<? extends T> o) {
  return new BlockingObservable<T>(o);
}

public Future<T> toFuture() {
  return BlockingOperatorToFuture.toFuture((Observable<T>)o);
}
```

#### BlockingOperatorToFuture.java

> [ReactiveX 关于toFuture的解读](http://reactivex.io/documentation/operators/to.html)
>
> The `toFuture` operator applies to the `BlockingObservable` subclass, so in order to use it, you must first convert your source Observable into a `BlockingObservable` by means of either the `BlockingObservable.from` method or the `Observable.toBlocking` operator.

`toFuture`只能作用于`BlockingObservable`所以也才会有上文想要转换为BlockingObservable的操作

```java
// 该操作将 源Observable转换为返回单个数据项的Future
public static <T> Future<T> toFuture(Observable<? extends T> that) {
  	// CountDownLatch 判断是否完成
    final CountDownLatch finished = new CountDownLatch(1);
  	// 存储执行结果
    final AtomicReference<T> value = new AtomicReference<T>();
  	// 存储错误结果
    final AtomicReference<Throwable> error = new AtomicReference<Throwable>();

  	// single()方法可以限制Observable只发送单条数据
  	// 如果有多条数据 会抛 IllegalArgumentException
  	// 如果没有数据可以发送 会抛 NoSuchElementException
    @SuppressWarnings("unchecked")
    final Subscription s = ((Observable<T>)that).single().subscribe(new Subscriber<T>() {
				// single()返回的Observable就可以对其进行标准的处理了
        @Override
        public void onCompleted() {
            finished.countDown();
        }

        @Override
        public void onError(Throwable e) {
            error.compareAndSet(null, e);
            finished.countDown();
        }

        @Override
        public void onNext(T v) {
            // "single" guarantees there is only one "onNext"
            value.set(v);
        }
    });
		
  	// 最后将Subscription返回的数据封装成Future,实现对应的逻辑
    return new Future<T>() {
			// 可以查看源码
    };

}
```

#### AbstractCommand.java

`AbstractCommand`是`toObservable`实现的地方,属于Hystrix的核心逻辑,代码较长,可以和方法调用的流程图一起食用.`toObservable`主要是完成缓存和创建Observable,requestLog的逻辑,当第一次创建Observable时,`applyHystrixSemantics`方法是Hystrix的语义实现,可以跳着看.

> **tips**: 下文中有很多 Action和 Function,他们很相似,都有call方法,但是区别在于Function有返回值,而Action没有,方法后跟着的数字代表有几个入参.Func0/Func3即没有入参和有三个入参

##### toObservable

`toObservable`代码较长且分层还是清晰的,所以下面一块一块写.其逻辑和文章开始提到的[Hystrix流程图](#Hystrix简单介绍)是完全一致的.

![toObservable.png](https://i.loli.net/2019/09/02/CpGLzZtPXHuwsv8.png)

```java
public Observable<R> toObservable() {
    final AbstractCommand<R> _cmd = this;
  	// 此处省略掉了很多个Action和Function,大部分是来做扫尾清理的函数,所以用到的时候再说
  
  	// defer在上篇rxjava入门中提到过,是一种创建型的操作符,每次订阅时会产生新的Observable,回调方法中所实现的才是真正我们需要的Observable
    return Observable.defer(new Func0<Observable<R>>() {
        @Override
        public Observable<R> call() {
          	
						// 校验命令的状态,保证其只执行一次
            if (!commandState.compareAndSet(CommandState.NOT_STARTED, CommandState.OBSERVABLE_CHAIN_CREATED)) {
                IllegalStateException ex = new IllegalStateException("This instance can only be executed once. Please instantiate a new instance.");
                //TODO make a new error type for this
                throw new HystrixRuntimeException(FailureType.BAD_REQUEST_EXCEPTION, _cmd.getClass(), getLogMessagePrefix() + " command executed multiple times - this is not permitted.", ex, null);
            }

            commandStartTimestamp = System.currentTimeMillis();
						// properties为当前command的所有属性
          	// 允许记录请求log时会保存当前执行的command
            if (properties.requestLogEnabled().get()) {
                // log this command execution regardless of what happened
                if (currentRequestLog != null) {
                    currentRequestLog.addExecutedCommand(_cmd);
                }
            }
						
          	// 是否开启了请求缓存
            final boolean requestCacheEnabled = isRequestCachingEnabled();
          	// 获取缓存key
            final String cacheKey = getCacheKey();

            // 开启缓存后,尝试从缓存中取
            if (requestCacheEnabled) {
                HystrixCommandResponseFromCache<R> fromCache = (HystrixCommandResponseFromCache<R>) requestCache.get(cacheKey);
                if (fromCache != null) {
                    isResponseFromCache = true;
                    return handleRequestCacheHitAndEmitValues(fromCache, _cmd);
                }
            }
          	// 没有开启请求缓存时,就执行正常的逻辑
            Observable<R> hystrixObservable =
              			// 这里又通过defer创建了我们需要的Observable
                    Observable.defer(applyHystrixSemantics)
              							// 发送前会先走一遍hook,默认executionHook是空实现的,所以这里就跳过了
                            .map(wrapWithAllOnNextHooks);
          
            // 得到最后的封装好的Observable后,将其放入缓存
            if (requestCacheEnabled && cacheKey != null) {
                // wrap it for caching
                HystrixCachedObservable<R> toCache = HystrixCachedObservable.from(hystrixObservable, _cmd);
                HystrixCommandResponseFromCache<R> fromCache = (HystrixCommandResponseFromCache<R>) requestCache.putIfAbsent(cacheKey, toCache);
                if (fromCache != null) {
                    // another thread beat us so we'll use the cached value instead
                    toCache.unsubscribe();
                    isResponseFromCache = true;
                    return handleRequestCacheHitAndEmitValues(fromCache, _cmd);
                } else {
                    // we just created an ObservableCommand so we cast and return it
                    afterCache = toCache.toObservable();
                }
            } else {
                afterCache = hystrixObservable;
            }

            return afterCache
              			// 终止时的操作
                    .doOnTerminate(terminateCommandCleanup)     // perform cleanup once (either on normal terminal state (this line), or unsubscribe (next line))
              			// 取消订阅时的操作
                    .doOnUnsubscribe(unsubscribeCommandCleanup) // perform cleanup once
              			// 完成时的操作
                    .doOnCompleted(fireOnCompletedHook);
        }
    }
                     
```

##### handleRequestCacheHitAndEmitValues

缓存击中时的处理

```java
private Observable<R> handleRequestCacheHitAndEmitValues(final HystrixCommandResponseFromCache<R> fromCache, final AbstractCommand<R> _cmd) {
        try {
          	// Hystrix中有大量的hook 如果有心做二次开发的,可以利用这些hook做到很完善的监控
            executionHook.onCacheHit(this);
        } catch (Throwable hookEx) {
            logger.warn("Error calling HystrixCommandExecutionHook.onCacheHit", hookEx);
        }   
  // 将缓存的结果赋给当前command
	return fromCache.toObservableWithStateCopiedInto(this)
    				// doOnTerminate 或者是后面看到的doOnUnsubscribe,doOnError,都指的是在响应onTerminate/onUnsubscribe/onError后的操作,即在Observable的生命周期上注册一个动作优雅的处理逻辑
            .doOnTerminate(new Action0() {
                @Override
                public void call() {
                  	// 命令最终状态的不同进行不同处理
                    if (commandState.compareAndSet(CommandState.OBSERVABLE_CHAIN_CREATED, CommandState.TERMINAL)) {
                        cleanUpAfterResponseFromCache(false); //user code never ran
                    } else if (commandState.compareAndSet(CommandState.USER_CODE_EXECUTED, CommandState.TERMINAL)) {
                        cleanUpAfterResponseFromCache(true); //user code did run
                    }
                }
            })
            .doOnUnsubscribe(new Action0() {
                @Override
                public void call() {
	                  // 命令最终状态的不同进行不同处理
                    if (commandState.compareAndSet(CommandState.OBSERVABLE_CHAIN_CREATED, CommandState.UNSUBSCRIBED)) {
                        cleanUpAfterResponseFromCache(false); //user code never ran
                    } else if (commandState.compareAndSet(CommandState.USER_CODE_EXECUTED, CommandState.UNSUBSCRIBED)) {
                        cleanUpAfterResponseFromCache(true); //user code did run
                    }
                }
            });
}       
```

##### applyHystrixSemantics

因为本片文章的主要目的是在讲执行流程,所以失败回退和断路器相关的就留到以后的文章中再写.

![applyHystrixSemantics.png](https://i.loli.net/2019/09/02/M3djoYyUaVGFptB.png)

```java
final Func0<Observable<R>> applyHystrixSemantics = new Func0<Observable<R>>() {
    @Override
    public Observable<R> call() {
      	// 不再订阅了就返回不发送数据的Observable
        if (commandState.get().equals(CommandState.UNSUBSCRIBED)) {
          	// 不发送任何数据或通知
            return Observable.never();
        }
        return applyHystrixSemantics(_cmd);
    }
};

private Observable<R> applyHystrixSemantics(final AbstractCommand<R> _cmd) {
	// 标记开始执行的hook
  // 如果hook内抛异常了,会快速失败且没有fallback处理
  executionHook.onStart(_cmd);

  /* determine if we're allowed to execute */
  // 断路器核心逻辑: 判断是否允许执行(TODO)
  if (circuitBreaker.allowRequest()) {
    // Hystrix自己造的信号量轮子,之所以不用juc下,官方解释为juc的Semphore实现太复杂,而且没有动态调节的信号量大小的能力,简而言之,不满足需求!
    // 根据不同隔离策略(线程池隔离/信号量隔离)获取不同的TryableSemphore
    final TryableSemaphore executionSemaphore = getExecutionSemaphore();
    // Semaphore释放标志
    final AtomicBoolean semaphoreHasBeenReleased = new AtomicBoolean(false);
    
    // 释放信号量的Action
    final Action0 singleSemaphoreRelease = new Action0() {
      @Override
      public void call() {
        if (semaphoreHasBeenReleased.compareAndSet(false, true)) {
          executionSemaphore.release();
        }
      }
    };

    // 异常处理
    final Action1<Throwable> markExceptionThrown = new Action1<Throwable>() {
      @Override
      public void call(Throwable t) {
        // HystrixEventNotifier是hystrix的插件,不同的事件发送不同的通知,默认是空实现.
        eventNotifier.markEvent(HystrixEventType.EXCEPTION_THROWN, commandKey);
      }
    };
		
    // 线程池隔离的TryableSemphore始终为true
    if (executionSemaphore.tryAcquire()) {
      try {
        /* used to track userThreadExecutionTime */
        // executionResult是一次命令执行的结果信息封装
        // 这里设置起始时间是为了记录命令的生命周期,执行过程中会set其他属性进去
        executionResult = executionResult.setInvocationStartTime(System.currentTimeMillis());
        return executeCommandAndObserve(_cmd)
          // 报错时的处理
          .doOnError(markExceptionThrown)
          // 终止时释放
          .doOnTerminate(singleSemaphoreRelease)
          // 取消订阅时释放
          .doOnUnsubscribe(singleSemaphoreRelease);
      } catch (RuntimeException e) {
        return Observable.error(e);
      }
    } else {
      // tryAcquire失败后会做fallback处理,TODO
      return handleSemaphoreRejectionViaFallback();
    }
  } else {
    // 断路器短路(拒绝请求)fallback处理 TODO
    return handleShortCircuitViaFallback();
  }
}

```

##### executeCommandAndObserve

![executeCommandAndObserve.png](https://i.loli.net/2019/09/02/qjDKmSk7QWUvO8X.png)

```java
/**
 * 执行run方法的地方
 */
private Observable<R> executeCommandAndObserve(final AbstractCommand<R> _cmd) {
  	// 获取当前上下文
    final HystrixRequestContext currentRequestContext = HystrixRequestContext.getContextForCurrentThread();

  	// 发送数据时的Action响应
    final Action1<R> markEmits = new Action1<R>() {
        @Override
        public void call(R r) {
          	// 如果onNext时需要上报时,做以下处理
            if (shouldOutputOnNextEvents()) {
              	// result标记
                executionResult = executionResult.addEvent(HystrixEventType.EMIT);
              	// 通知
                eventNotifier.markEvent(HystrixEventType.EMIT, commandKey);
            }
          	// commandIsScalar是一个我不解的地方,在网上也没有查到好的解释
          	// 该方法为抽象方法,有HystrixCommand实现返回true.HystrixObservableCommand返回false
            if (commandIsScalar()) {
              	// 耗时
                long latency = System.currentTimeMillis() - executionResult.getStartTimestamp();
              	// 通知
                eventNotifier.markCommandExecution(getCommandKey(), properties.executionIsolationStrategy().get(), (int) latency, executionResult.getOrderedList());
                eventNotifier.markEvent(HystrixEventType.SUCCESS, commandKey);
                executionResult = executionResult.addEvent((int) latency, HystrixEventType.SUCCESS);
              	// 断路器标记成功(断路器半开时的反馈,决定是否关闭断路器)
                circuitBreaker.markSuccess();
            }
        }
    };

    final Action0 markOnCompleted = new Action0() {
        @Override
        public void call() {
            if (!commandIsScalar()) {
							// 同markEmits 类似处理
            }
        }
    };

  	// 失败回退的逻辑
    final Func1<Throwable, Observable<R>> handleFallback = new Func1<Throwable, Observable<R>>() {
        @Override
        public Observable<R> call(Throwable t) {
          // 不是重点略过了
        }
    };

  	// 请求上下文的处理
    final Action1<Notification<? super R>> setRequestContext = new Action1<Notification<? super R>>() {
        @Override
        public void call(Notification<? super R> rNotification) {
            setRequestContextIfNeeded(currentRequestContext);
        }
    };

    Observable<R> execution;
  	// 如果有执行超时限制,会将包装后的Observable再转变为支持TimeOut的
    if (properties.executionTimeoutEnabled().get()) {
      	// 根据不同的隔离策略包装为不同的Observable
        execution = executeCommandWithSpecifiedIsolation(_cmd)
          			// lift 是rxjava中一种基本操作符 可以将Observable转换成另一种Observable
          			// 包装为带有超时限制的Observable
                .lift(new HystrixObservableTimeoutOperator<R>(_cmd));
    } else {
        execution = executeCommandWithSpecifiedIsolation(_cmd);
    }

    return execution.doOnNext(markEmits)
            .doOnCompleted(markOnCompleted)
            .onErrorResumeNext(handleFallback)
            .doOnEach(setRequestContext);
}
```

##### executeCommandWithSpecifiedIsolation

根据不同的隔离策略创建不同的执行`Observable`

![executeCommandSpecfi.png](https://i.loli.net/2019/09/02/GCKHtruabSk3FDA.png)

```java
private Observable<R> executeCommandWithSpecifiedIsolation(final AbstractCommand<R> _cmd) {
    if (properties.executionIsolationStrategy().get() == ExecutionIsolationStrategy.THREAD) {
        // mark that we are executing in a thread (even if we end up being rejected we still were a THREAD execution and not SEMAPHORE)
        return Observable.defer(new Func0<Observable<R>>() {
            @Override
            public Observable<R> call() {
              	// 由于源码太长,这里只关注正常的流程,需要详细了解可以去看看源码
                if (threadState.compareAndSet(ThreadState.NOT_USING_THREAD, ThreadState.STARTED)) {
                    try {
                        return getUserExecutionObservable(_cmd);
                    } catch (Throwable ex) {
                        return Observable.error(ex);
                    }
                } else {
                    //command has already been unsubscribed, so return immediately
                    return Observable.error(new RuntimeException("unsubscribed before executing run()"));
                }
            }})
        .doOnTerminate(new Action0() {})
        .doOnUnsubscribe(new Action0() {})
        // 指定在某一个线程上执行,是rxjava中很重要的线程调度的概念
        .subscribeOn(threadPool.getScheduler(new Func0<Boolean>() {
        }));
    } else { // 信号量隔离策略
        return Observable.defer(new Func0<Observable<R>>() {
						// 逻辑与线程池大致相同
        });
    }
}
```

##### getUserExecutionObservable

获取用户执行的逻辑

```java
private Observable<R> getUserExecutionObservable(final AbstractCommand<R> _cmd) {
    Observable<R> userObservable;

    try {
      	// getExecutionObservable是抽象方法,有HystrixCommand自行实现
        userObservable = getExecutionObservable();
    } catch (Throwable ex) {
        // the run() method is a user provided implementation so can throw instead of using Observable.onError
        // so we catch it here and turn it into Observable.error
        userObservable = Observable.error(ex);
    }
		// 将Observable作其他中转
    return userObservable
            .lift(new ExecutionHookApplication(_cmd))
            .lift(new DeprecatedOnRunHookApplication(_cmd));
}
```

**lift操作符**

lift可以转换成一个新的Observable,它很像一个代理,将原来的Observable代理到自己这里,订阅时通知原来的Observable发送数据,经自己这里流转加工处理再返回给订阅者.`Map/FlatMap`操作符底层其实就是用的`lift`进行实现的.

##### getExecutionObservable

```java
@Override
final protected Observable<R> getExecutionObservable() {
  return Observable.defer(new Func0<Observable<R>>() {
    @Override
    public Observable<R> call() {
      try {
        // just操作符就是直接执行的Observable
        // run方法就是我们实现的业务逻辑: Hello World~
        return Observable.just(run());
      } catch (Throwable ex) {
        return Observable.error(ex);
      }
    }
  }).doOnSubscribe(new Action0() {
    @Override
    public void call() {
     	// 执行订阅时将执行线程记为当前线程,必要时我们可以interrupt
      executionThread.set(Thread.currentThread());
    }
  });
}
```



## 总结

希望自己能把埋下的坑一一填完: 容错机制,metrics,断路器等等...

## 参考

1. [Hystrix How it Works](https://github.com/Netflix/Hystrix/wiki/How-it-Works)
2. [ReactiveX官网](http://reactivex.io/documentation/observable.html)
3. [阮一峰: 中文技术文档写作规范](https://github.com/ruanyf/document-style-guide)
4. [RxJava lift 原理解析](https://blog.csdn.net/qq_24530405/article/details/66969886)