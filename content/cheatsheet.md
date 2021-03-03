---
title: "常用键备份"
date: 2020-01-22T13:19:18+08:00
draft: false
description: "vim | linux | idea | git"
---

## Linux

### wget

> https://www.centos.bz/2011/03/15-example-the-ultimate-guide-to-linux-wget-download/

```bash
# 静默下载
wget -qO- https://example.com/a.zip 
```

### curl

> https://www.ruanyifeng.com/blog/2019/09/curl-reference.html

```bash
# 等同于 wget 下载
curl -L -O https://example.com/a.zip 
```

## 常用idea快捷键

- 大小写切换<kbd>command</kbd> <kbd>shift</kbd> <kbd>u</kbd>
- surround with  <kbd>option</kbd><kbd>command</kbd><kbd>t</kbd>
- 进入实现类  <kbd>option</kbd><kbd>command</kbd><kbd>b</kbd>
- 查找当前类中的方法和变量 <kbd>command</kbd><kbd>F12</kbd>

## 自定义快捷键

- 右键调出长下文菜单  `command+shift+L`

## git

```bash
# 同步远程仓库,删除本地仓库中无用的分支(保持与远程仓库分支一致,远程没有的就删掉)
git remote prune origin

# 批量删除 利用 grep 语法以及 xargs 传参
git branch | grep '匹配字符串' | xargs git branch -D
```

## vim

### 移动

<C-o> 跳转到光标上次停留的位置(往后调)

<C-i> 同上(往前跳)

**zz**: 将当前行移动到屏幕中央

### 编辑

**A**: 在当前行末尾编辑

**I**:在当前行首编辑

分别更改这些配对标点符号中的文本内容
ci’、ci”、ci(、ci[、ci{、ci< -

分别删除这些配对标点符号中的文本内容 
di’、di”、di(或dib、di[、di{或diB、di< -

分别复制这些配对标点符号中的文本内容 
yi’、yi”、yi(、yi[、yi{、yi< -

分别选中这些配对标点符号中的文本内容
vi’、vi”、vi(、vi[、vi{、vi< -

## docker

```bash
docker ps -a # 获取当前所有进程
docker image ls # 列出所有image
docker run -d {image} # 后台运行image
docker exec -it {name} bash # 进入容器内部
```

## 配置

**vs ~/.vimrc** 热更新配置