---
title: "rust踩坑笔记"
date: 2019-08-20T13:19:18+08:00
draft: true
tags: ["rust"]
description: "「rust学习笔记」"
keywords: ["学习笔记","rust"]
---

<!--more-->

# 基本类型-Primitives

## 标准类型 Scalar Types

1. 有符号整型 signed integers: `i8`, `i16`, `i32`, `i64`, `i128` and `isize` (pointer size)

2. 无符号整型 unsigned integers: `u8`, `u16`, `u32`, `u64`, `u128` and `usize` (pointer size)

3. 浮点型 floating point: `f32`, `f64`

4. 字符 `char` Unicode scalar values like `'a'`, `'α'` and `'∞'` (4 bytes each)

5. 布尔 `bool` either `true` or `false`

6.  the unit type `()`, whose only possible value is an empty tuple: `()`

   >  我的理解就是个empty吧

数值字面,没有后缀时.默认整数为 `i32`,浮点数  `f64`

### 三级目录

1. 有符号整型 signed integers: `i8`, `i16`, `i32`, `i64`, `i128` and `isize` (pointer size)

2. 无符号整型 unsigned integers: `u8`, `u16`, `u32`, `u64`, `u128` and `usize` (pointer size)

3. 浮点型 floating point: `f32`, `f64`

4. 字符 `char` Unicode scalar values like `'a'`, `'α'` and `'∞'` (4 bytes each)

5. 布尔 `bool` either `true` or `false`

6. the unit type `()`, whose only possible value is an empty tuple: `()`

   > 我的理解就是个empty吧

数值字面,没有后缀时.默认整数为 `i32`,浮点数  `f64`

#### 四级目录

1. 有符号整型 signed integers: `i8`, `i16`, `i32`, `i64`, `i128` and `isize` (pointer size)

2. 无符号整型 unsigned integers: `u8`, `u16`, `u32`, `u64`, `u128` and `usize` (pointer size)

3. 浮点型 floating point: `f32`, `f64`

4. 字符 `char` Unicode scalar values like `'a'`, `'α'` and `'∞'` (4 bytes each)

5. 布尔 `bool` either `true` or `false`

6. the unit type `()`, whose only possible value is an empty tuple: `()`

   > 我的理解就是个empty吧

数值字面,没有后缀时.默认整数为 `i32`,浮点数  `f64`

## 复合类型 Compound Types

1. 数组 array [1,2,3]
2. 元组 tuple (1,true,"str",'a'...)



Note: 默认变量赋值后是不可变的,需要重复赋值需要用`mut` 修饰

```rust
let immutable = 1;
immutable = 2; // ERROR

let mut immutable = 1;
immutable = 2; // SUCCESS
```



# 所有权踩坑

1. 可变引用在作用域下**有且只能有一个可变引用**

2. 不可在**拥有不可变引用**的同时**拥有可变引用**,除非作用域没有重叠.即在引用可变引用时,不可变引用已经失效了.

   ```rust
   let mut s = String::from("hello");
   
   let r1 = &s; // 没问题
   let r2 = &s; // 没问题
   let r3 = &mut s; // 大问题
   
   println!("{}, {}, and {}", r1, r2, r3);
   
   //////////////////////////////////////
   let mut s = String::from("hello");
   
   let r1 = &s; // 没问题
   let r2 = &s; // 没问题
   println!("{} and {}", r1, r2);
   // 此位置之后 r1 和 r2 不再使用
   
   let r3 = &mut s; // 没问题
   println!("{}", r3);
   ```

   