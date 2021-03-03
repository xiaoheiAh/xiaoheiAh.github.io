---
title: "[LeetCode In Rust]026-Remove Duplicates From Sorted Array"
date: 2019-08-20T15:54:47+08:00
draft: false
tags: ["leetcode", "rust"]
description: "rust实现leetcode 有序数组去重(Remove Duplicates From Sorted Array)"
keywords: ["Remove Duplicates From Sorted Array","rust"]
categories: ["leetcode"]
---

<!--more-->

```rust
pub fn remove_duplicates(nums: &mut Vec<i32>) -> i32 {
    if nums.is_empty() { return 0 }
    let mut idx = 0;
    for i in idx .. nums.len() {
        if nums[i].gt(&nums[idx]) {
            idx += 1;
            nums.swap(i,idx);
        }
    }
    (idx + 1) as i32
}
```

