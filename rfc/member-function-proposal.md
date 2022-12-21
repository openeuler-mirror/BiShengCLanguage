# 成员函数
proposed by Fan Changchun `@fanchangchun`

## 需求描述

类型支持成员函数，有利于用 interface 对类型做统一抽象。这个提案是泛型和interface的先导。

1. 需要支持对遗留的 C 代码中定义的类型，新增成员函数，且写在新文件中。比如 `a.h` 中有 `struct A { ... };` 的定义，我们可以在 `b.h` 中为 `struct A` 新增成员函数。类似 go/swift/Rust 里面的类型扩展。
2. 允许声明扩展出来的成员函数满足某个 interface。
3. 需要支持 “实例成员函数” 和 “静态成员函数”。一个有 this 参数，另外一个没有。
4. 需要支持给内置类型增加成员函数。比如给 int 新增一个`int64_t hash_code()` 成员函数。
5. 需要分别支持成员函数的声明和定义。一般在 `.hbs` 文件中只有声明，在 `.cbs` 文件中写定义。
6. 成员函数可以被赋值给函数指针。
7. 成员函数可以指定 linkage。

## 语法设计

1. 引入 `this` 关键字。如果存在 `this` 参数，它只能是第一个参数。
2. 【语法】选择声明和实现是同样语法，去掉函数体是声明，有函数体是定义。
   
   ```c
   
   ```

return-type type-name :: func-name (parameter-list) {}

```
示例：

```c
// 声明
const char * int::to_string(const int* this);
// 定义
const char * int::to_string(const int* this) {
    // ...
}
```

3. 成员函数也需要保持先声明后调用的顺序。如果前面一个函数的定义要调用后面一个函数，需要在更前面对这个函数做声明。
4. 函数签名中 `this` 需要显式写出来，用来区分 “实例成员函数” 和 “静态成员函数”。`this` 的类型为扩展类型的指针类型，或者 const/volatile 修饰的指针类型。
   
   还有另外一个常见的设计，实例成员函数默认有 this 参数，静态成员函数用 static 关键字修饰。不这么选择的理由是：
   
   * 标准 C 里面的 static 修饰代表 internal linkage。复用 static 关键字的含义，可能会造成误解。
   * 我们后续可能会允许 this 是其它的类型（比如借用类型），独立的 this 参数比较容易修饰它的类型。
5. 如果成员函数的第一个参数名字是 this，那么它就是一个实例成员函数。调用实例成员函数与访问成员变量类似。用实例类型调用，用 `.` 符号；用指针类型调用，用 `->` 符号。但也允许用普通函数调用的方式调用：
   
   ```c
   typedef struct{ ... } M;
   void M::f(M* this) {}
   int main() {
       M x;
       x.f(); // 允许
       M::f(&x); // 允许
   }
   ```
6. 如果成员函数的第一个参数名字不是 this，那么调用这个函数，就跟调用全局函数类似，区别只是函数名变成 `type-name::func-name`。

示例：

```c
// a.h 文件
struct A {
    int x;
};

void struct A::f(struct A* this); // 声明
const char * struct A::h(); // 声明


// a.bsc 文件
#include "a.h"

void struct A::f(struct A* this) { // 定义
    printf("f \n");
}

static void struct A::g(struct A* this) { // 一个新的成员函数定义，linkage 是 internal 的
    printf("g \n");
}

const char * struct A::h() { // 非实例成员函数的定义，参数没有 this
    return "A";
}
int main() {
    struct A v = {0};
    v.x;
    v.f(); // 调用
    
    struct A* p = &v;
    p->x;
    p->g(); // 调用
    
    printf(struct A::h()); // 调用非实例成员函数
    
    void (*fp1)(struct A *) = &struct A::f; // 获取函数指针
    void (*fp2)(struct A *) = struct A::g;  // 获取函数指针，也允许不用 &
}
```

## 其它规则

1. 只允许对 complete type 新增成员函数。
2. 新增成员函数不影响原类型的 layout 包括 size 和 alignment。
3. 成员函数不允许重载，不允许重定义。如果两个头文件中对同一个类型新增了同名的成员函数，那么在一个编译单元中 include 这两个头文件，是编译错误。
4. 成员函数的名字不允许与成员变量相同，适用于 struct, union, enum。
5. 成员函数允许有 declaration-specifiers。
6. 成员函数允许被赋值给函数指针。
7. <del>没有静态成员变量，只有静态成员函数</del>。
8. 暂时禁止对 “函数类型” 添加成员函数。
9. 暂时禁止用整数字面量、浮点数字面量、compound literal 直接调用成员函数。因为可能有语法冲突或者类型解析问题。

## 翻译为标准 C 代码

成员函数这个功能是完全可以被翻译为标准 C 代码的。

在声明、定义处，将函数名从 `type-name::func-name` 按一定规则拼接为标准 C 的 identifier 即可。

1. 找到 type-name 的 canonical type name
2. 拼接 `canonical-type-name`  `__`   `func-name`

示例如下：

```c
struct A {
    int x;
};
typedef struct A AA;

void AA::f(AA* this) {}
```

首先找到 AA 类型的原始定义是 `struct A`，函数名为 `f`，最后拼接出来的函数签名是：

```c
void struct_A__f(struct A* this);
```

对应的，在函数调用方：

* 把`var-name.func-name(arg-list)` 替换为 `mangled-func-name(&var-name)`
* 把`pointer-name -> func-name(arg-list)` 替换为 `mangled-func-name(pointer-name)`