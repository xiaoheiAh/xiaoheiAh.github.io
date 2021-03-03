---
title: "使用 GitHub Action 持续集成你的博客"
date: 2020-04-03T09:26:43+08:00
draft: false
description: "使用 GitHub 原生的持续集成工具自动部署 hugo 的生成的静态博客"
tags : ["CI/CD"]
---



记录下自己的部署踩坑经历。

<!--more-->

## GitHub Actions[^1]

GitHub 官方出品的持续集成工具，真香。与 GitlabCI, Travis CI, Circle CI 都是一个性质的工具，我觉得 GitHub Action 最大的优势在于其依托的强大的开源生态，以及原生支持 CI/CD 的能力不需要再集成第三方的 CI/CD 工具。官方出品的 [Actions Marketplace](https://github.com/marketplace?type=actions) 已经有很多类型的 Action 可供选择，开箱即用。很多功能我也还没有去研究，仅仅先用来自动部署个博客。

### 优点

1. 支持**主流操作系统**容器：通常来讲就是 Linux / Windows / MacOS / Arm 都支持。
2. 支持所有语言：这应该是标配。
3. 支持多平台（Matrix Builds）同时构建：同时在多个操作系统进行测试或发布，减少构建时间
4. 支持自建集成环境（Self-hosted Runner[^3]）：如果觉得 GitHub 默认的容器配置[^2] （大概是 7G 内存，双核 CPU）不够用支持自建。
5. 基于事件（Event）触发：push / issue 创建 / PR 提交都可以出发，完全可以基于此完成一套自动化维护项目的流程。

### 缺点

暂时没有发现，对我来说很够用了……

### 概念/术语

<img src="https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20200406182106.png" alt="Workflow 结构" style="zoom:50%;" />

1. Workflow：GitHub 是对一次 CI/CD 的过程定义为 Workflow，中间可能经历过代码拉取，编译，测试，打包，发布，通知等多个过程。
2. Action： 一个独立的运行任务，多个 Action 组成 steps 来创建一个 Job。一组 Action（Actions） 逻辑相同就可以被复用，可以发布到 Actions Marketplace 供他人使用。
3. Steps：一个多个 Actions 形成的步骤。一个 step 可以只是一个命令，也可以是一个 Action。
4. Job：Steps 中的 Action 一个一个走完就完成了一个 Job。Job 下的所有 step 是运行在同一个容器中的，所以可以共享文件系统。
5. Workflow File：Workflow 的配置文件，yaml 格式。GitHub 规定需要存放在 `{$REPO_HOME}/.github/workflow/`。

### 限制

![使用限制](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20200406113232.png)

微软收购 GitHub 以后很多人都觉得要商业化收费了，转 Gitlab 了。但是没想到现在是越做越强，从上图可以知道，对于开发者来说是非常友好的。Public 库免费使用 GitHub Action，Private 库 Free 版本每月 2000 分钟的免费使用时长，对大多数开发者来讲是绝对够用的。

* Job 执行时间：每个 Job 最多允许执行 6 小时，超过该时间会自动终止 Job。
* Workflow 执行时间：每个 workflow 最多允许运行 72 小时，超时会自动取消该工作流。
* API 请求数限制：当执行过程中有 API 调用的情况时，限制为每个 Repo 1000 req/hours
* 并行 Job 数量：Free 版本是 20 个，特别注意的是 MacOS 的 Job 只能并行 5 个。

## 使用示例

目前 GitHub Actions 已经发布正式版了，理论上所有仓库下都会有一个 Actions 的 Tab。只要在项目的根目录下创建 `.github/workflow` 文件夹，并添加一个正确配置的 yaml 文件就可以触发集成并在仓库的 Actions Tab 下面有实时的日志。如下是一个当推送到指定分支后自动部署静态博客的工作流。工作流的语法可以参考[workflow-syntax-for-github-actions](https://help.github.com/en/actions/reference/workflow-syntax-for-github-actions)。

```yaml
name: github pages # 工作流的名称

# 触发工作流的事件 Event 下面设置的是当 push 到 source 分支后触发
# 其他的事件还有：pull_request/page_build/release
# 可参考：https://help.github.com/en/actions/reference/events-that-trigger-workflows
on:	
  push:
    branches:
    - source

# jobs 即工作流中的执行任务
jobs:
  build-deploy: # job-id
    runs-on: ubuntu-18.04 # 容器环境
    # needs: other-job 如果有依赖其他的 job 可以如此配置
    
    # 任务步骤集合
    steps:
    - name: Checkout	# 步骤名称
      uses: actions/checkout@v2	# 引用可重用的 actions，比如这个就是 GitHub 官方的用于拉取代码的actions `@` 后面可以跟指定的分支或者 release 的版本或者特定的commit
      with:	# 当前 actions 的一些配置
        submodules: true # 如果项目有依赖 Git 子项目时可以设为 true，拉取的时候会一并拉取下来

    - name: Setup Hugo
      uses: peaceiris/actions-hugo@v2	# 这也是一个开源的 actions 用于安装 Hugo
      with:
        hugo-version: 'latest'
        # extended: true

    - name: Build
      run: hugo --minify # 一个 step 也可以直接用 run 执行命令。如果有多个命令可以如下使用
      #run: |
    		#npm ci
    		#npm run build

    - name: Deploy
      uses: peaceiris/actions-gh-pages@v3 # 开源 actions 用于部署
      with:
        github_token: ${{ secrets.GITHUB_TOKEN}} # GitHub 读写仓库的权限token，自动生成无需关心
        publish_branch: master
```

如果你使用 Hugo 做博客系统的话，使用上面的配置放在指定的文件夹下，理论上来说可以开箱即用（我就没有做其他的配置）。推送一次到 source 分支后，可以前往 Actions Tab 进行查看。

![push to remote](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20200406191554.png)

该图中失败的那次可以发现它运行了 6h+，所以自动终止了。也算是印证了 Github Actions 的策略。偶尔会遇到像卡死一样的问题，手动重启下就可以了。

### GITHUB_TOKEN[^4]

​	`GITHUB_TOKEN` 是 GitHub 自动为工作流创建的 token。当需要权限认证时，可以通过 `${{ secrets.GITHUB_TOKEN}}` 在整个工作流中全局使用。比如上面的示例工作流配置，在部署博客时需要向分支推送编译后的静态文件，此时就需要进行校验。

#### 有哪些权限？

以下的权限对于常规部署已经足够了。如果想要更完全的权限就需要在个人设置中设置相应的密钥，比如 `Personal Access Token` , 并使用 `${{screts.SECRET_NAME}}` 进行调用。

| Permission          | Access type | Access by forked repos |
| ------------------- | ----------- | ---------------------- |
| actions             | read/write  | read                   |
| checks              | read/write  | read                   |
| contents            | read/write  | read                   |
| deployments         | read/write  | read                   |
| issues              | read/write  | read                   |
| metadata            | read        | read                   |
| packages            | read/write  | read                   |
| pull requests       | read/write  | read                   |
| repository projects | read/write  | read                   |
| statuses            | read/write  | read                   |

## 总结

GitHub Actions 给我的感觉就是对开发者友好也好玩，如果有维护开源项目，也爱折腾的同学肯定可以感受到它的益处。有很多功能还待发掘，比如说多平台支持（开发跨平台的 App 时一次执行多端编译打包发布岂不快哉），各种事件Hook（当有 issue/PR/release 时通知核心开发或者给予反馈者一些提示完善信息）都可以尝试下。

## References

[^1]:[Github Actions 官方文档] https://help.github.com/en/actions

[^2]: [GitHub-hosted Runner 配置] https://help.github.com/en/actions/reference/virtual-environments-for-github-hosted-runners#supported-runners-and-hardware-resources
[^3]: [Self-hosted Runner 搭建文档] https://help.github.com/en/actions/hosting-your-own-runners
[^4]: [GitHub Token Auth] https://help.github.com/en/actions/configuring-and-managing-workflows/authenticating-with-the-github_token

