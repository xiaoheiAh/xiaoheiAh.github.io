---
title: "简历"
date: 2018-08-15T13:19:18+08:00
draft: true
utter: false
---

### 赵云翔

------

#### 基本信息

<table><tbody><tr><td style="text-align:left;"><span>手机: 13164692069</span></td><td style="text-align:left;"><span>邮箱: </span><a href="mailto:xiaohei.zyx@gmail.com" target="_blank" class="url">xiaohei.zyx@gmail.com</a></td></tr><tr><td style="text-align:left;"><span>学历: 本科</span></td><td style="text-align:left;"><span>英语水平: 四级</span></td></tr><tr><td style="text-align:left;"><span>博客: </span><a href="https://blog.xiaohei.im"><span>blog.xiaohei.im</span></a></td><td style="text-align:left;"><span>当前状态: 上海在职</span></td></tr><tr><td style="text-align:left;"><span>工作经验: 三年</span></td><td style="text-align:left;"><span>应聘职位: Java 开发工程师</span></td></tr></tbody></table>

### 技术栈

------


1. 语言基础: Java/Scala,看过 JDK 中部分源码(集合/并发包),了解 JVM 组成结构
2. 数据库: 熟悉 MySQL 的使用,了解常见的索引结构以及慢查询优化的策略
3. 框架: 熟练使用 SpringBoot/MyBatis/JOOQ
4. 中间件: 熟悉RabbitMQ/Redis/Hystrix ,了解 Redis 的数据结构及常见应用场景,了解 Hystrix 的执行过程
5. 分布式相关: 了解过共识算法 Raft,在组内组织过分享
6. 工具相关: 熟练使用Maven/Gradle/Git/Vim,会使用常见 Linux 命令
7. 开源: 参与过分布式事务框架 [github.com/seata](https://github.com/seata/seata/pulls?q=author:xiaoheiAh) 的开发

### 工作经历

------
<table><thead><tr><th><span>企鹅杏仁</span></th><th><span>2019.06 - 至今</span></th></tr></thead><tbody><tr><td colspan="2"><span>担任后端研发工程师, 参与公司单体服务向服务化演进，负责线上咨询，服务订购，消息推送等核心服务的开发维护。有系统不停机平滑迁移经验，参与过亿级数据应用分表落地。</span></td></tr><tr><td colspan="2"><strong><span>技术栈</span></strong><span>: Scala/Play/SpringBoot/MySQL/RabbitMQ/ElasticJob/Feign/JOOQ/Hystrix/Redis</span></td></tr></tbody>
<thead><tr><th><span>上海大搜车</span></th><th><span>2018.04 - 2019.06</span></th></tr></thead><tbody><tr><td colspan="2"><span>担任后端研发工程师，负责 ToB 新车业务及基础车型服务的研发维护。</span></td></tr><tr><td colspan="2"><strong><span>技术栈</span></strong><span>: Spring全家桶/MySQL/Redis</span></td></tr></tbody>


### 项目经历

------

#### 医患咨询中台

随着业务发展，为满足在不同场景下（B/C端）能稳定提供通用的医生咨询能力，便将早期的线上问诊模块下沉为通用咨询能力。利用 DDD 对业务进行问题领域划分，涉及子域包括咨询订单域，咨询域，消息域。目前咨询中台已承接线上所有咨询业务场景，通过良好的接口设计以及文档说明降低接入成本。

##### 个人职责

* 针对亿级数据的迁移方案设计落地
* 咨询订单域实现，通过核心流程配置化满足不同业务的需求，业务异步化保证最终一致性，避免分布式事务
* 端到端消息**秒级**推送实现及推送可靠性方案的设计
* 完成亿级数据分表的设计及落地，吞吐量提升近**20%**，延迟降低近**40%**

#### 药品服务

药品是目前公司线上**流水**占比最大的营收来源，业务内容主要涉及药品商城，药品订单，药房中控，药品供应链等几大块。通过可演进的配置化方式满足各业务线不同的运营需求。

##### 个人职责

* 负责药品服务通知异步化改造，降低核心链路延迟

* 基于 **Trie 树**改造内置药品搜索,查询从秒级优化到毫秒级

#### 统一埋点平台

向上层业务提供友好的埋点功能，向上层屏蔽埋点细节，尽量减少埋点对业务的侵入。在埋点服务完成对应的数据抓取，转换，校验以及与第三方埋点服务的通信。利用 RabbitMQ 作为埋点消息的通道,通过单独实例/内网通信/RabbitMQ异步确认的机制保障埋点及上层业务的可靠性。目前服务QPS在 **2K** 左右。

##### 个人职责

* 负责埋点平台的模块设计以及部分模块的开发,利用依赖倒置原则对模块进行解耦
* 消息中间件的可靠性保证及重试设计
* 负责咨询中台相关埋点事件的接入

#### 车型服务搭建

对接不同经销商的车型数据，与公司的车型进行匹配映射。

##### 个人职责

-  独立负责整个服务，通过 RocketMQ 同步匹配的车型数据 ，对外暴露 dubbo 的车型接口，为交易提供可靠数据来源。
- 多租户（多个经销商数据需要隔离）的实现通过添加经销商标记，ThreadLocal 以及 alibaba/druid 重写 SQL 实现。

### 教育经历

------

*2014-2018 / 湖北文理学院 / 物联网工程 / 本科*

