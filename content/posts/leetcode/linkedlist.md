---
title: "「LeetCode」链表题解"
date: 2019-12-26T18:22:05+08:00
draft: false
tags: ["leetcode"]
description: "leetcode | linkedlist | 题解"
keywords: ["linkedlist"]
categories: ["leetcode"]
---

<!--more-->

链表需要注意的问题:

* 边界: 头结点尾结点的处理,链表长度为1时的处理
* 多画图,跟一次循环,边界情况也画图试试
* 思路大多都是 **快慢指针**

#### [No.19 => Remove Nth Node From End of List](https://leetcode.com/problems/remove-nth-node-from-end-of-list/) **Medium**

```java
public ListNode removeNthFromEnd(ListNode head, int n) {
  // 快慢指针
  ListNode fast = head,slow = head,prev = null;
  while(fast.next != null) {
    if (--n <= 0) {
      // 先走 n 步后,slow 再走
      prev = slow;
      slow = slow.next;
    }
    fast = fast.next;
  }
  // fast 走完,slow 刚好到倒数 n 的位置
  // 删除 slow 节点
  if( prev == null) {
    // 说明删除的是头结点
    if(slow.next == null) {
      // 说明链表只有一个节点.且需要删除的就是这个.
      head = null;
    } else {
      // 大于一个节点就需要把 head 指向 slow.next
      head = prev = slow.next;
    }
  } else {
    prev.next = slow.next;
  }
  return head;
}
```

#### [No.2 => Add Two Numbers](https://leetcode.com/problems/add-two-numbers/) **Medium**

思路: 就按着这个链表顺序加,然后生成一个链表就自然是倒序的了.

```java
public ListNode addTwoNumbers(ListNode l1, ListNode l2) {
  // 一次累加,reverse
  ListNode result = new ListNode(0);
  ListNode head = result;
  int carry = 0;
  while(l1 != null || l2 != null || carry > 0) {
    int v1 = 0;
    int v2 = 0;
    if(l1 != null) {
      v1 = l1.val;
      l1 = l1.next;
    }
    if(l2 != null) {
      v2 = l2.val;
      l2 = l2.next;
    }
    int sum = v1 + v2 + carry;
    result.next = new ListNode( sum % 10);
    result = result.next;
    carry = sum / 10 ;
  }
  return head.next;
}
```

#### [No.21 =>  Merge Two Sorted Lists](https://leetcode.com/problems/merge-two-sorted-lists/) **EASY**

##### **非递归**

```java
public ListNode mergeTwoLists(ListNode l1, ListNode l2) {
    // 边界条件需要判断
    if (l1 == null) return l2;
    if (l2 == null) return l1;
    ListNode dummy = new ListNode(0), head = dummy;
    while(l1 !=null || l2 != null) {
        if(l1 == null) {
            head.next = l2;
            l2 = l2.next;
        } else if (l2 == null) {
            head.next = l1;
            l1 = l1.next;
        } else if (l1.val >= l2.val) {
            head.next = l2;
            l2 = l2.next;
        } else {
            head.next = l1;
            l1 = l1.next;
        }
        head = head.next;
    }
    return dummy.next;
}
```
##### **递归**

```java
public ListNode mergeTwoLists(ListNode l1, ListNode l2) {
    // 边界条件需要判断
    if (l1 == null) return l2;
    if (l2 == null) return l1;
    if (l1.val <= l2.val) {
        l1.next = mergeTwoLists(l1.next,l2);
        return l1;
    } else {
        l2.next = mergeTwoLists(l1, l2.next);
        return l2;
    }
}
```
#### [No.24 =>  Swap Nodes in Pairs](https://leetcode.com/problems/swap-nodes-in-pairs/) **Medium**

思路: 走两步然后替换这两个node,考虑head为空和头两个节点交换的情况

```java
public ListNode swapPairs(ListNode head) {
  if(head == null) {
    return null;
  }
  int step = 1;
  ListNode prev = null;
  ListNode curr = head;
  while(curr.next != null) {
    if(++step % 2 == 0) {
      // 每两个反转链表
      if (prev == null) {
        // 是头结点与第二个节点反转
        ListNode second = curr.next;
        curr.next = second.next;
        second.next = curr;
        head = second;
      } else {
        // 中间节点 swap
        ListNode second = curr.next;
        curr.next = curr.next.next;
        prev.next = second;
        second.next = curr;
      }
    } else {
      // 走两步~
      prev = curr;
      curr = curr.next;
    }
  }
  return head;
}
```

