---
title: "RxJava入门"
date: 2018-08-21T16:09:48+08:00
draft: false
tags : ["rxjava","响应式编程"]
description: "「RxJava」| 背压 | 观察者模式 | 响应式编程"
keywords: ["学习笔记","rust","背压","backpressure","响应式编程"]
categories: ["Hystrix"]
---

>  本文基于 rxjava 1.x 版本

<!--more-->

## 前言

写这篇文章是因为之前在看Hystrix时,觉得响应式编程很有意思,之前也了解到Spring5主打特性就是响应式,就想来试试水,入个门.本文主要介绍RxJava的特点,入门操作

## RxJava是什么

### Reactive X

`ReactiveX`是使用`Observable`序列来组合异步操作且基于事件驱动的一个库.其继承自[观察者模式](https://zh.wikipedia.org/wiki/观察者模式)来支持数据流或者事件流通过添加操作符(operators)的方式来声明式的操作,并抽象出对低级别线程(low-level thread),同步,线程安全,并发数据结构,非阻塞IO问题的关注.

ReactiveX 在不同语言中都有实现,RxJava 只是在JVM上实现的一套罢了.

### 概念

> 观察者模式是该框架的灵魂~

![WX20190821-171445.png](https://i.loli.net/2019/08/21/PT56HZ2obO8vU3V.png)

上图可以表述为: **观察者**(Observer) **订阅**(subscribe)**被观察者**(Observable),当Observable产生事件或数据时,会调用Observer的方法进行回调.

听起来有点别扭,这里举一个形象点的例子.

**显示器开关**

显示器开关即为 Observable, 显示器为 Observer,这两个组件就会形成联系.当开关按下时,显示器就会通电点亮,这里即可抽象成Observable发出一个事件,Observer对事件做了处理.做什么样的处理其实在Subscribe时就已经决定了.

**回调方法**

在subscribe时会要求实现对应的回调方法,标准方法有以下三个:

* **onNext**

  Observable调用这个方法发射数据，方法的参数就是Observable发射的数据，这个方法可能会被调用多次，取决于你的实现。

* **onError**

  当Observable遇到错误或者无法返回期望的数据时会调用这个方法，这个调用会终止Observable，后续不会再调用onNext和onCompleted，onError方法的参数是抛出的异常。

* **onCompleted**

  正常终止，如果没有遇到错误，Observable在最后一次调用onNext之后调用此方法。

### "Hot" or "Cold" Observables

Observable何时开始发送数据呢?基于此问题,可以将Observable分为两类: `Hot` & `Cold` . 可以理解为主动型和被动型.

**Hot Observable**: Observable一经创建,就会开始发送数据. 所以后面订阅的Observer可能消费不到Observable完整的数据.

**Cold Observable**: Observable会等到有Observer订阅时才开始发送数据,此时Observer会消费到完整的数据

## RxJava入门

### Hello World

```java
Observable.create(new Observable.OnSubscribe<String>() {
    @Override
    public void call(Subscriber<? super String> subscriber) {
      subscriber.onNext("Hello World");
      subscriber.onCompleted();
      //subscriber.onError(new RuntimeException("error"));
    }
  	}).subscribe(new Subscriber<String>() {
    @Override
    public void onCompleted() {
      System.out.println("观察结束啦~~~");
    }

    @Override
    public void onError(Throwable e) {
      System.out.println("观察出错啦~~~");
    }

    @Override
    public void onNext(String s) {
      System.out.println("onNext:" + s);
    }
  });
}
```

```java
// onNext:Hello World
// 观察结束啦~~~
// 注释掉上一行 打开下一行注释 就会输出
// onNext:Hello World
// 观察出错啦~~~
```

上述即为一个标准的创建观察者被观察者并订阅,实现订阅逻辑.

**疑问**

1. 为什么`subscribe`方法的参数是`Subscriber`呢?

   在rxjava中Observer是接口,Subscriber实现了Observer并提供了拓展.所以普遍用这个.

2. 为什么是Observable.subscribe(Observer)?用上面的显示器开关的例子来说就相当于显示器开关订阅显示器.

   为了保证流式风格~rxjava提供了一系列的操作符来对Observable发出的数据做处理,流式风格可以使操作符使用起来更友好.所以就当做Observable订阅了Observer吧:man_facepalming:

### 操作符 Operators

单纯的使用上面的`Hello World`撸码只能说是观察者模式的运用罢了,操作符才是`ReactiveX`最强大的地方.我们可以通过功能不同的操作符对Observable发出的数据做过滤(filter),转换(map)来满足业务的需求.其实就可以当作是Java8的`lambda`特性.

> Observable在经过操作符处理后还是一个Observable,对应上述的**流式风格**

案例: 假设我们需要监听鼠标在一个直角坐标系中的点击,取得所有在第一象限点击的坐标.

![marble.png](https://i.loli.net/2019/08/22/eQnOjomU7IufBpk.png)

从该流程图可以看出,鼠标点击后会发出很多数据,一次点击一个点,我们对数据进行filter,得到了下方时间轴上的数据源.这就是我们想要的.下面来看下常用的操作符有哪些?

#### 创建型操作符

> 用于创建Observable对象的操作符

##### Create

创建一个Observable,需要传递一个`Function`来完成调用Observer的逻辑.

一个标准的Observable必须只能调用一次(**Exactly Once**)`onCompleted`或者`onError`,并且在调用后不能再调用Observer的其他方法(eg: onNext).

**sample code**

```java
Observable.create(new Observable.OnSubscribe<Integer>() {
    @Override
    public void call(Subscriber<? super Integer> observer) {
        try {
            if (!observer.isUnsubscribed()) {
                for (int i = 1; i < 5; i++) {
                    observer.onNext(i);
                }
                observer.onCompleted();
            }
        } catch (Exception e) {
            observer.onError(e);
        }
    }
 } ).subscribe(new Subscriber<Integer>() {
        @Override
        public void onNext(Integer item) {
            System.out.println("Next: " + item);
        }

        @Override
        public void onError(Throwable error) {
            System.err.println("Error: " + error.getMessage());
        }

        @Override
        public void onCompleted() {
            System.out.println("Sequence complete.");
        }
    });
```

```bash
Next: 1
Next: 2
Next: 3
Next: 4
Sequence complete.
```

##### Defer

直到有Observer订阅时才会创建,并且会为每一个Observer创建新的Observable,这样可以保证所有Observer可以看到相同的数据,并且从头开始消费.

**sample code**

```java
Observable<String> defer = Observable.defer(new Func0<Observable<String>>() {
    @Override
    public Observable<String> call() {
        return Observable.just("Hello", "World");
    }
});

defer.subscribe(new Subscriber<String>() {
    @Override
    public void onCompleted() {
        System.out.println("第一个订阅完成啦~");
    }

    @Override
    public void onError(Throwable e) {
        System.out.println("第一个订阅报错啦~");
    }

    @Override
    public void onNext(String s) {
        System.out.println("第一个订阅收到:" + s);
    }
});

defer.subscribe(new Subscriber<String>() {
		//与上一个订阅逻辑相同
});

```

```bash
第一个订阅收到:Hello
第一个订阅收到:World
第一个订阅完成啦~
第二个订阅收到:Hello
第二个订阅收到:World
第二个订阅完成啦~
```

**Note:**

Defer在RxJava中的实现其实有点像指派,可以看到构建时,传参为`Func0<Observable<T>>`,Observer真正订阅的是传参中的Observable.

##### Just

在上文`Defer`中代码中就用了`Just`,指的是可以发送特定的数据.代码一致就不作展示了.

##### Interval

可以按照指定时间间隔从0开始发送无限递增序列.

###### 参数

* initalDelay   延迟多长时间开始第一次发送
* period          指定时间间隔
* unit               时间单位

如下例子:延迟0秒后开始发送,每1秒发送一次. 因为sleep 100秒,会发送0-99终止

**sample code**

```java
Observable.interval(0,1,TimeUnit.SECONDS).subscribe(new Action1<Long>() {
  	// 这里只实现了OnNext方法,onError和onCompleted可以有默认实现.一种偷懒写法
    @Override
    public void call(Long aLong) {
        System.out.println(aLong);
    }
});
try {
  	//阻塞当前线程使程序一直跑
    TimeUnit.SECONDS.sleep(100);
} catch (InterruptedException e) {
    e.printStackTrace();
}
```

#### 转换操作符

> 将Observable发出的数据进行各类转换的操作符

##### Buffer

![buffer.png](https://i.loli.net/2019/08/22/IC3vbhSDGgUYku5.png)

如上图所示,buffer定期将数据收集到集合中,并将集合打包发送.

**sample code**

```java
Observable.just(2,3,5,6)
        .buffer(3)
        .subscribe(new Action1<List<Integer>>() {
            @Override
            public void call(List<Integer> integers) {
                System.out.println(integers);
            }
        });
```

```bash
[2, 3, 5]
[6]
```

**Window**

window和buffer是非常像的两个操作符,区别在于buffer会将存起来的item打包再发出去,而window则只是单纯的将item堆起来,达到阈值再发出去,不对原数据结构做修改.

![window.png](https://i.loli.net/2019/08/22/kqIb5j6xfPDdOZn.png)

**sample code**

```java
Observable.just(2,3,5,6)
        .window(3)
        .subscribe(new Action1<Observable<Integer>>() {
            @Override
            public void call(Observable<Integer> integerObservable) {
                integerObservable.subscribe(new Action1<Integer>() {
                    @Override
                    public void call(Integer integer) {
                        // do anything
                    }
                });
            }
        });
```

#### 合并操作符

> 将多个Observable合并为一个的操作符

##### Zip

使用一个函数组合多个Observable发射的数据集合，然后再发射这个结果。如果多个Observable发射的数据量不一样，则以最少的Observable为标准进行组合.

![zip.png](https://i.loli.net/2019/08/22/Nu4TCMEHKGA3Y1V.png)

**sample code**

```java
Observable<Integer>  observable1=Observable.just(1,2,3,4);
Observable<Integer>  observable2=Observable.just(4,5,6);
Observable.zip(observable1, observable2, new Func2<Integer, Integer, String>() {
    @Override
    public String call(Integer item1, Integer item2) {
        return item1+"and"+item2;
    }
}).subscribe(new Action1<String>() {
    @Override
    public void call(String s) {
        System.out.println(s);
    }
}); 
```

```bash
1and4
2and5
3and6
```

#### 背压操作符

> 用于平衡Observer消费速度,Observable生产速度的操作符

背压是指在异步场景中,被观察者发送事件速度远快于观察者的处理速度的情况下，一种告诉上游的被观察者降低发送速度的策略.下图可以很好阐释背压机制是如何运行的.

![backpressure.png](https://i.loli.net/2019/09/02/4TyQFgBkIAO1R2c.png)

宗旨就是**下游告诉上游我能处理多少你就给我发多少.**

```java
//被观察者将产生100000个事件
Observable observable=Observable.range(1,100000);
observable.observeOn(Schedulers.newThread())
        .subscribe(new Subscriber() {
            @Override
            public void onCompleted() {

            }
            @Override
            public void onError(Throwable e) {

            }
            @Override
            public void onNext(Object o) {
                try {
                    TimeUnit.SECONDS.sleep(1);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
              	System.out.println("on Next Request...");
                request(1);
            }
        });
```

##### 背压支持

上述样例代码中创建Observable使用的是`range`操作符,这是因为他是支持背压的,如果用`interval`,request的方法将不起作用.因为`interval`不支持背压.那什么样的Observable支持背压呢?

在前面介绍概念时,有提到过`Hot`&`Cold`的区别,`Hot`类型的Observable,即一经创建就开始发送,**不支持**背压,`Cold`类型的Observable也只是**部分**支持.

##### onBackpressurebuffer/onBackpressureDrop

不支持背压的操作符我们可以如何实现背压呢?就通过`onBackpressurebuffer/onBackpressureDrop`来实现.顾名思义一个是缓存,一个是丢弃.

这里以`drop`方式来展示.

```java
Observable.interval(1, TimeUnit.MILLISECONDS)
  .onBackpressureDrop()
  //指定observer调度io线程上,并将缓存size置为1,这个缓存会提前将数据存好在消费,
  //默认在PC上是128,设置小一点可以快速的看到drop的效果
  .observeOn(Schedulers.io(), 1)
  .subscribe(new Subscriber<Long>() {
    @Override
    public void onCompleted() {

    }

    @Override
    public void onError(Throwable e) {
      System.out.println("Error:" + e.getMessage());
    }

    @Override
    public void onNext(Long aLong) {
      System.out.println("订阅 " + aLong);
      try {
        TimeUnit.MILLISECONDS.sleep(100);
      } catch (InterruptedException e) {
        e.printStackTrace();
      }
    }
 	})
```

```bash
订阅 0
订阅 103
订阅 207
订阅 300
订阅 417
订阅 519
订阅 624
订阅 726
订阅 827
订阅 931
订阅 1035
订阅 1138
订阅 1244
订阅 1349
```

可以很明显的看出很多数据被丢掉了,这就是背压的效果.

## 总结

写了这么多后,想来说说自己的感受.

1. 转变思想: 响应式编程的思想跟我们现在后端开发思路是有区别的.可能刚开始会不适应.
2. 不易调试: 流式风格写着爽,调着难

## 参考

[ReactiveX官网](http://reactivex.io/documentation/)

[关于RxJava最友好的文章——背压（Backpressure)](https://zhuanlan.zhihu.com/p/24473022)

[如何形象地描述RxJava中的背压和流控机制？](http://zhangtielei.com/posts/blog-rxjava-backpressure.html)