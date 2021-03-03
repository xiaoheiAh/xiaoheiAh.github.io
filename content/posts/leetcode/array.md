---
title: "「LeetCode」数组题解"
date: 2019-12-26T17:22:05+08:00
draft: false
tags: ["leetcode"]
description: "leetcode | array | 题解"
keywords: ["leetcode|array"]
categories: ["leetcode"]
---

<!--more-->

### [Easy => 1252. Cells with Odd Values in a Matrix](https://leetcode.com/problems/cells-with-odd-values-in-a-matrix/submissions/)

```java
    public int oddCells(int n, int m, int[][] indices) {
        boolean[] oddRows = new boolean[n];
        boolean[] oddCols = new boolean[m];
        
        for(int[] item : indices) {
            // 遍历 indices 获取每一列每一行的出现次数是否为奇数
            // 异或: 相同为0 不同为1 
            oddRows[item[0]] ^= true;
            oddCols[item[1]] ^= true;
        }
        
        int oddCnt = 0;
        for(int i = 0; i < n; i++) {
            for(int j = 0; j < m; j++) {
                // 行列出现 奇数次 + 偶数次 才能是产生奇数
                oddCnt += oddRows[i] != oddCols[j] ? 1 : 0;
            }
        }
        // Time Complexity: O(m*n + indices.length)
        return oddCnt;
    }
```

### [EASY =>26. Remove Duplicates from Sorted Array](https://leetcode.com/problems/remove-duplicates-from-sorted-array/)

快慢指针的运用

```java
public int removeDuplicates(int[] nums) {
    int slow = 0;
    int fast = 1;
    while(fast < nums.length) {
        if(nums[slow] != nums[fast]) {
            nums[++slow] = nums[fast++];
        } else {
            fast++;
        }
    }
    return slow + 1;
}
```
### [EASY => 27. Remove Element](https://leetcode.com/problems/remove-element/)

快慢指针的运用

```java
public int removeElement(int[] nums, int val) {
    int curr = 0;
    int p = 0;
    while(p < nums.length) {
        if(nums[p] == val ) {
            p++;
        } else {
            nums[curr++] = nums[p++];
        }
    }
    return curr;
}		
```