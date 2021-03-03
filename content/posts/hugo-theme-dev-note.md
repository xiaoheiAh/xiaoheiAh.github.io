---
title: "Hexo => Hugo主题移植记录"
date: 2019-09-23T19:08:35+08:00
draft: false
markup: "mmark"
description: "「 hugo」| 主题开发 | hexo 移植"
tags : ["hugo"]
---

> 最近使用[Hugo](https://gohugo.io/)作为博客引擎后,闲不下来总想去找一些简单好看的主题.在[官方的主题列表](https://themes.gohugo.io/)搜罗了一圈后,选择了[yinyang](https://github.com/joway/hugo-theme-yinyang),非常简单,但是用了一段时间还是想找个功能全点的,无意中瞄到了一个博主的博客,主题特别吸引我,但是是 `hexo` 平台的,搜了半天也没有人移植,就自己来吧~ 移植的过程中,遇到了挺多问题,也是这些问题慢慢的熟悉了hugo的模板结构.下面就来写一写自己遇到的问题~

<!--more-->

## 页面变量参数

> https://gohugo.io/variables/

hugo的页面有基本的变量(我更愿意称为**属性**,根据这些属性来实现我们的主题模板.最主要的有三类:`Site`, `Page`, `Taxonomy`.

### .Site

> 站点相关的属性,即config.toml(yml)文件中的配置.

在页面模板中,我们可以使用`{{- .Site.Autor }}`这样的方式来获取你想要的站点属性.具体的站点属性可以查看https://gohugo.io/variables/site/. `.Site` 属于全局配置,在 **作用域** 得当的情况下是可以正常调用的.非正常情况我们下面再讲.

#### 常用属性

1. `.Site.Pages` : 获取所有文章(包含生成的一些分类页,比如说 `标签页`),按时间倒序排序.返回是一个数组.我们经常用来渲染一个列表.比如 `归档` 页面.

2. `.Site.Taxonomies` : 获取所有的分类(这里的分类是广义上的),可以获取到按`tag`分类的集合,也可以获取到按`category`分类的集合,可以用这个属性来完成`分类`的页面.下面这段代码就代表着我可以拿到所有的 `分类页` ,循环得到分类页的链接和标题.

   ```html
   {{- range .Site.Taxonomies.categories }}
   <li><a href="{{ .Page.Permalink }}">{{ .Page.Title }}</a></li>
   {{- end }}
   ```

3. `.Site.Params` 可以获取到我们在`config.toml`的`Params`标签下设置的内容.也是很重要的属性.比如说下面的例子.我可以设置日期的格式化样式,展示成你想要的类型.

   ```html
   <p>{{ .Date.Format (.Site.Params.dateFormatToUse | default "2006-01-02")}}</p>
   ```

### .Page

> 页面中定义的属性.

页面属性可以大致分为两部分,一个是`Hugo`原生的属性,一个是每一篇文章的文件头,即`front matter`中的属性.具体的属性可以在https://gohugo.io/variables/page/查看. 在一个页面的作用域中使用时可以直接调用.比如我们想要知道页面的创建日期就可以直接 `{{ .Date }}` 即可.

#### 常用属性

1. `.Date/.Title/.ReadingTime/.WordCount` 见名知意
2. `.Permalink/.RelPermalink` 永久链接及相对连接
3. `.Summary` 摘要,默认70字
4. `.Pages` 为什么页面中还有一个这样的属性呢? `Page`是包含生成的`分类页`, `标签页`的,所有当处于这些页面时会返回一个集合,若是我们自己真正写的文件,即`markdown`文件,会返回`nil`的.

#### .Taxonomies

> 用作内容分类的管理. 我们经常在写文章时会写上 `categories` 或者 `tags`, 这些标签类目就是 `.Taxonomies` 的集中展示, `Hugo` 默认会有 `categories` 和 `tags` 两种分类. 你也可以自己再自定义设置. 具体参考: https://gohugo.io/content-management/taxonomies

#### 使用案例

> 官方提供了多种 `Template` 实现常用的遍历.

我通常会用来写标签页(`tags`)和分类页(`categories`). 直接调用 `.Taxonomies` 会获得所有的分类项(即: `tags`, `categories`, `自定义分类项`), `.Taxonomies.tags` 就可以获得所有的标签,以及标签下的所有文章.以下就是我的主题中 `标签` 页的实现逻辑.

```html
{{- $tags := .Site.Taxonomies.tags }}
<main class="main" role="main">
    <article class="article article-tags post-type-list" itemscope="">
        <header class="article-header">
            <h1 itemprop="name" class="hidden-xs">{{- .Title }}</h1>
            <p class="text-muted hidden-xs">{{- T "total_tag" (len $tags) }}</p>
            <nav role="navigation" id="nav-main" class="okayNav">
                <ul>
                    <li><a href="{{- "tags" | relURL }}">{{- T "nav_all" }}</a></li>
                    {{- range $tags }}
                    <li><a href="{{ .Page.Permalink }}">{{ .Page.Title }}</a></li>
                    {{- end }}
                </ul>
            </nav>
        </header>
        <!-- /header -->
        <div class="article-body">
            {{- range $name, $taxonomy := $tags  }}
            <h3 class="panel-title mb-1x">
                <a href="{{ "/tags/" | relURL}}{{ $name | urlize }}" title="#{{- $name }}"># {{ $name }}</a>
                <small class="text-muted">(Total {{- .Count }} articles)</small>
            </h3>
            <div class="row">
                {{- range $taxonomy }}
                <div class="col-md-6">
                    {{ .Page.Scratch.Set "type" "card"}}
                    {{- partial "item-post.html" . }}
                </div>
                {{- end }}
            </div>
            {{- end }}
        </div>
    </article>
</main>
```

## 上下文传递

> 刚开始写 Hugo 的页面时,最让我头疼的地方就在在于此.现在想想他的逻辑是很标准的.不同的代码块上下文隔离.

在Hugo中,上下文的传递一般是靠`.`符号来完成的. 用的最多的就是再组装页面时,需要将当前页面的作用域传递到 `partial` 的页面中去以便组装进来的页面可以获得当前页面的属性.

以下是我的 `baseof.html` 页面, 可以看到 ` partial` 相关的代码中都有 `.` 符号, 这里就是将当前页面的属性传递下去了, 其他页面也就可以正常使用该页面的属性了.

```html
<!DOCTYPE html>
<html lang="{{ .Site.Language }}">
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
    <title>
      {{- block "title" . -}}
      {{ if .IsPage }}
        {{ .Title }} - {{ .Site.Title }}
      {{ else}}
        {{ .Site.Title}}{{ end }}
      {{- end -}}
    </title>
    {{ partial "head.html" . }}
  </head>
  <body class="main-center" itemscope itemtype="http://schema.org/WebPage">
    {{- partial "header.html" .}}
    {{- if and (.Site.Params.sidebar) (or (ne .Params.sidebar "none") (ne .Params.sidebar "custom"))}}
        {{- partial "sidebar.html" . }}
    {{end}}
    {{ block "content" . }}{{ end }}
    {{- partial "footer.html" . }}
    {{- partial "script.html" . }}
  </body>
</html>

```

## 页面组织

### baseof.html

`baseof` 可以理解为一种模板,符合规范定义的页面都会按照 `baseof.html` 的框架完成最后的渲染,具体可以查看[官网页](https://gohugo.io/templates/base/), 以本次移植主题的 `baseof.html` 来说一下.

```html
<!DOCTYPE html>
<html lang="{{ .Site.Language }}">
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
    <title>
      {{- block "title" . -}}
      {{ if .IsPage }}
        {{ .Title }} - {{ .Site.Title }}
      {{ else}}
        {{ .Site.Title}}{{ end }}
      {{- end -}}
    </title>
    {{ partial "head.html" . }}
  </head>
  <body class="main-center" itemscope itemtype="http://schema.org/WebPage">
    {{- partial "header.html" .}}
    {{- if and (.Site.Params.sidebar) (or (ne .Params.sidebar "none") (ne .Params.sidebar "custom"))}}
        {{- partial "sidebar.html" . }}
    {{end}}
    {{ block "content" . }}{{ end }}
    {{- partial "footer.html" . }}
    {{- partial "script.html" . }}
  </body>
</html>


```

可以看到上面的页面中就是一个完整的 `HTML` 结构,我在其中组装了很多页面,比如`head`,`header`,`footer`等等,这些在最后渲染的时候都会加入进来组成一个完整的页面.

在上面还有一个关键字 **block**, 比如 `{{ block "title" }}`, `{{ block "content"}}`.该关键字允许你自定义一个模板嵌进来, 只要按照规定的方式来.比如说我的文章页 `single.html`.

```html
{{- define "content"}}
<main class="main" role="main">
  {{- partial "article.html" . }}
</main>
{{- end}}
```

这里我们定义了 `content` 的模板, 和 `baseof.html` 的模板呼应,在渲染一篇文章时,就会将`single.html` 嵌入 `baseof.html` 生成最后的页面了.

### 模板页面查询规则

Hugo要怎么知道文章页还是标签页对应的模板是什么呢?答案: 有一套以多个属性作为依据的查询各类模板的标准.具体可以查看[官网页](https://gohugo.io/templates/lookup-order/).

以文章页来举例, `Hugo` 官网上的内容页寻址规则如下:

![single-lookup-order](https://cdn.jsdelivr.net/gh/xiaoheiAh/imgs@master/20191015150712.png)

由上可见,会按照该顺序依次往下找,我一般会写在`layouts/_default/single.html` 下,这样可以在所有页面下通用.

这里有个小坑也是之前文档没看好遇到的: 标签页和分类页这种对应的查找规则要按照[该指引](https://gohugo.io/templates/lookup-order/#examples-layout-lookup-for-taxonomy-terms-pages).

## 参考

1. https://harmstyler.me/posts/2019/how-to-pass-variables-to-a-partial-template-in-hugo/
2. https://www.qikqiak.com/post/hugo-integrated-algolia-search/