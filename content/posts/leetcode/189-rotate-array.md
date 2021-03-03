---
title: "[LeetCode In Rust]189-Rotate Array"
date: 2019-08-21T15:29:34+08:00
draft: false
tags: ["leetcode", "rust"]
description: "rust实现leetcode 反转数组(Rotate Array)"
keywords: ["Rotate Array","rust"]
categories: ["leetcode"]
---

<!--more-->

Given an array, rotate the array to the right by *k* steps, where *k* is non-negative.

**Example 1:**

```bash
Input: [1,2,3,4,5,6,7] and k = 3
Output: [5,6,7,1,2,3,4]
Explanation:
rotate 1 steps to the right: [7,1,2,3,4,5,6]
rotate 2 steps to the right: [6,7,1,2,3,4,5]
rotate 3 steps to the right: [5,6,7,1,2,3,4]
```

**Example 2:**

```bash
Input: [-1,-100,3,99] and k = 2
Output: [3,99,-1,-100]
Explanation: 
rotate 1 steps to the right: [99,-1,-100,3]
rotate 2 steps to the right: [3,99,-1,-100]
```

**Note:**

- Try to come up as many solutions as you can, there are at least 3 different ways to solve this problem.
- Could you do it in-place with O(1) extra space?



**思路**

依次反转前半部分及后半部分,最后反转整个数组

eg: 1,2,3,4,5,6,7  k=3

1. 反转前半部分

   4,3,2,1,5,6,7

2. 反转后半部分

   4,3,2,1,7,6,5

3. 反转整个数组

   5,6,7,1,2,3,4



**Solution 1**

```rust
pub fn rotate(nums: &mut Vec<i32>, k: i32) {
    if nums.is_empty() || k <= 0 { return; }

    let o_len = nums.len();
    let mod_k = k as usize % o_len;
    reverse(nums, 0, o_len - mod_k - 1);
    reverse(nums, o_len - mod_k, o_len - 1);
    reverse(nums, 0, o_len - 1);
}

pub fn reverse(nums: &mut Vec<i32>, start: usize, end: usize) {
    let mut o_start = start;
    let mut o_end = end;
    while o_start < o_end {
        nums.swap(o_start, o_end);
        o_start += 1;
        o_end -= 1;
    }
}
```


**Solution 2**

> api 解法,效率不高,但好看

```rust
pub fn rotate(nums: &mut Vec<i32>, k: i32) {
    if nums.is_empty() { return; }

    let mod_k = k % nums.len() as i32;

    for _ in 0..mod_k as usize {
        let item = nums.pop().unwrap();
        nums.insert(0, item);
    }
}
```
