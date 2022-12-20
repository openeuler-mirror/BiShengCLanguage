# 泛型
proposed by Fan Changchun `@fanchangchun`

## 功能需求

经过前期讨论，我们已经确定，泛型实例化采取 “代码复制” 的方案。因为这样才能获取最佳性能，但在某些情况下可能会有代码膨胀的问题。我们会让 interface 也可以提供动态派遣的方式，来解决这个问题。

1. 支持定义泛型全局函数，泛型成员函数，泛型类型（struct, union），泛型接口（interface）
2. 支持泛型参数携带默认值（Rust只允许在类型定义的时候可以有默认值，泛型函数不允许）
3. 支持泛型类型推导，特别是函数调用的时候，根据实际类型参数，推导出泛型类型实参
   
   ```rust
   use std::fmt::Display;
   
   fn f<T>(x: &T) where T : Display {
       println!("{}", x);
       println!("{}", std::any::type_name::<T>());
   }
   
   fn main() {
       let v: i32 = 1;
       // 函数调用，不需要显式指定泛型参数 f::<i32>(&v);
       f(&v);
   }
   ```
4. 支持泛型约束
5. 支持常量泛型（可用于对数组类型的统一抽象）
6. 支持变长参数泛型（有利于写出类型安全的 printf 这种函数）
7. 支持泛型特化（有助于性能优化）
8. 支持泛型类型的 type alias
9. 不支持泛型协变、逆变

考虑到我们的开发节奏，我们应该尽可能让泛型的基础能力最先开发出来，然后其他的功能就可以继续。而不需要等泛型的所有功能都完备之后再开始其他功能的开发。

从开发节奏上考虑，我提议分三个部分：

1. 支持成员函数语法。支持泛型类型、泛型函数定义。支持泛型实例化，给定 “泛型定义” 和 “泛型实参”，我们可以生成对应的代码。
   （在这一步我们不做泛型约束检查，而是在实例化完成之后做一遍检查。这样可以最快使得泛型功能从前端到后端打通，不阻碍其它功能。）
2. 支持成员函数，支持 interface 的定义，支持类型扩展 interface。支持泛型的 where 约束条件，允许用 interface 对泛型参数做约束。
3. 支持泛型的其它高级功能。

本文档描述第一阶段需要实现的特性功能。

## 语法（本期的主要部分）

### 定义泛型函数

C 标准规定的函数定义语法：

```
attr-spec-seq(optional) specifiers-and-qualifiers parameter-list-declarator function-body
```

示例：

```c
[[maybe_unused]] 
static inline int max(int a, int b)
{
    return a>b?a:b;
}
```

泛型函数：

* 在函数名和参数列表之间加入 type-parameter-list，在尖括号中声明一系列的类型参数。

示例：【结论：不做 where 约束，自由一点】

```c
// 泛型函数
[[maybe_unused]]
static inline 
T max<T>(T a, T b)
{

}

struct hashmap<K, V> {
    
}
```

### 定义泛型类型

C 标准规定的 struct/union 定义语法：

```
struct attr-spec-seq(optional) name(optional) { struct-declaration-list }	
union attr-spec-seq(optional) name(optional) { struct-declaration-list }
```

enum 类型定义不支持泛型。

泛型类型定义在 name 的后面加上 type-parameter-list 。示例：

```c
// 泛型类型
struct MyS<T> {
    T x;
    int y;
};
```

注意：我们不允许泛型函数和泛型类型，只有单独的 ”声明“ 而没有 ”定义“。

与普通函数不同，泛型函数如果需要被多个编译单元使用，它的函数体必须写在 `.h` 里面。示例如下：

【语法】

```c
struct MyS<T> {
    T val;
};

T MyS<U>::f<T>(MyS<U> arg) {
   
}

void MyS<T>::f<U>() {
    
}
```

在泛型上下文中，新引入的泛型类型参数名，不能与外层的泛型类型参数同名。

### 泛型实例化

为泛型类型的形参提供实际参数，就是泛型的实例化。语法为：

* 函数名后面加尖括号以及类型实参
* 类型名后面加尖括号以及类型实参

示例：

```c
int main() {
    (void)(*g)(int) = f<char>;
    
	struct MyS<int> x;  // 泛型类型实例化
	x.g<char>();  // 泛型函数实例化
    f<void *>(NULL); // 泛型函数实例化
	return 0;
}

extern struct MyS<int>; // 声明外部有这个类型。

//
```

【遗留】：支持强制实例化某个版本，支持 extern 某个实例化版本的类型。

规则：

* 泛型的实参类型必须是 complete type。（因为 void 类型永远是 incomplete type，所以 void 不允许作为泛型实参使用。）
* 没有实例化的泛型类型、泛型函数，是无法被 C 调用的。也不会生成代码。
* 实例化之后的泛型类型、泛型函数，需要有一个确定性的 name mangle 规则。且这个 mangle name 需要是合法的 C 语言的 identifier，方便做源源变换。
* 我们会把实例化之后的代码重做一遍语义检查。在泛型定义的时候只做基础的语法检查。

## 其它规则