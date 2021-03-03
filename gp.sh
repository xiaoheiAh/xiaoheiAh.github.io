#!/bin/sh
echo "===== 开始推送到github ====="

git add . >> /tmp/git.log 2>&1
git commit -m "$1" >> /tmp/git.log 2>&1
echo "===== 提交信息:"$1" ====="
git push origin master >> /tmp/git.log 2>&1
echo "===== github 推送完成 ====="
echo "===== 推送到 hugo-theme-pure ====="
sh pure-gh-pages.sh >> /tmp/git.log 2>&1
echo "===== hugo-theme-pure 推送完成 ====="
