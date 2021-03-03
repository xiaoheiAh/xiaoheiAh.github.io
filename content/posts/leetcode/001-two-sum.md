---
title: "[LeetCode In Rust]001-Two Sum"
date: 2019-08-16T18:22:05+08:00
draft: false
tags: ["leetcode", "rust"]
description: "rust实现leetcode 两数之和(Two Sum)"
keywords: ["two sum","rust"]
categories: ["leetcode"]
---

<!--more-->

```rust
pub fn two_sum(nums: Vec<i32>, target: i32) -> Vec<i32> {
    let map: HashMap<i32, usize> = nums.iter().enumerate().map(|(idx, &data)| (data, idx)).collect();

    nums.iter().enumerate().find(|(idx, &num)| {
        match  map.get(&(target - num)) {
            Some(&idx_in_map) => idx_in_map != *idx,
            None => false,
        }
    }).map(|(idx, &num)| vec![*map.get(&(target - num)).unwrap() as i32, idx as i32]).unwrap()

}

```



```rust
pub fn two_sum_v2(nums: Vec<i32>, target: i32) -> Vec<i32> {
    let map: HashMap<i32, usize> = nums.iter().enumerate().map(|(idx, &data)| (data, idx)).collect();

    for (i,&num) in nums.iter().enumerate() {
        match map.get(&(target - num) ) {
            Some(&x) => {
                if i != x {
                    return vec![i as i32, x as i32]
                }
            },
            None => continue,
        }
    }
    vec![]
}
```

