# Beike AspectD AOP 注解使用说明

> 基于 `inner/transformer/plugins/aop/` 源码分析整理

---

## 前置规则（所有注解通用）

### 1. 必须标记 `@Aspect()` + `@pragma("vm:entry-point")`

```dart
@Aspect()
@pragma("vm:entry-point")
class MyHookClass {
  @pragma("vm:entry-point")
  MyHookClass(); // 构造也要加 pragma
  
  // ... 注解方法
}
```

### 2. 方法名前缀含义

| 前缀          | 含义                                        |
| ------------- | ------------------------------------------- |
| `-methodName` | 实例方法（instance method）                 |
| `+methodName` | 静态方法 / 构造方法（static / constructor） |

框架解析时会自动剥离这个前缀，并据此设置 `isStatic` 标志。

---

## 六种注解详解

---

### 1. `@Call` — 拦截**调用点**

**含义**：拦截所有调用目标方法的地方（调用方被改写），目标方法本身**不变**。

```dart
@Call("package:example/main.dart", "_MyHomePageState", "-_incrementCounter")
@pragma("vm:entry-point")
void myHook(PointCut pointcut) {
  print('before call');
  pointcut.proceed(); // 调用原始方法
}
```

**签名格式**：
```
@Call(importUri, clsName, "-/+methodName", {isRegex: false})
```

**工作原理**：  
遍历整个 component 中所有 `InstanceInvocation` / `StaticInvocation` / `ConstructorInvocation`，将匹配的调用点替换为调用你的 hook 方法，`pointcut.proceed()` 内部再调用原始方法。

**支持的目标**：

| 场景           | 写法示例                               |
| -------------- | -------------------------------------- |
| 实例方法       | `"-methodName"`                        |
| 静态方法       | `"+methodName"`                        |
| 构造方法       | `"+ClassName"` 或 `"+ClassName.named"` |
| 库级别静态方法 | `clsName` 填空字符串 `""`              |

**支持正则**：`isRegex: true`，三个参数（importUri、clsName、methodName）均按正则匹配。

**局限**：
- 拦截的是**每一个调用处**，多处调用就插入多份代码，性能开销随调用点数量线性增长。
- 无法拦截通过反射/`Function.apply` 的间接调用。
- `excludeCoreLib: true` 可排除 Flutter 框架内部对自身的调用（避免死循环）。

---

### 2. `@Execute` — 拦截**方法体执行**

**含义**：直接替换目标方法体，所有调用该方法的地方都会走 hook 逻辑（执行方被改写）。

```dart
@Execute("package:example/main.dart", "_MyHomePageState", "-_incrementCounter")
@pragma("vm:entry-point")
void myHook(PointCut pointcut) {
  print('before execute');
  pointcut.proceed(); // 执行原始方法体
}
```

**签名格式**：
```
@Execute(importUri, clsName, "-/+methodName", {isRegex: false})
```

**工作原理**：  
找到目标类/库中的 `Procedure` 或 `Constructor`，将其 `function.body` 替换为调用 hook 方法的代码块，`pointcut.proceed()` 再跑原有 body。

**与 @Call 的核心区别**：

|              | @Call                | @Execute       |
| ------------ | -------------------- | -------------- |
| 改写位置     | 所有调用点           | 目标方法体本身 |
| 代码插入份数 | N 份（N = 调用次数） | 1 份           |
| 对调用方透明 | 是                   | 是             |

**支持的目标**：实例方法、静态方法、构造方法、库级别函数，同样支持正则。

**局限**：
- 目标方法必须有可替换的 body（抽象方法 `abstract` 无法 hook）。
- 泛型方法（`typeParameters.isNotEmpty`）在**库级别函数**路径上被跳过（代码中有 `procedure.function.typeParameters.isEmpty` 过滤）。
- 如果目标方法是 `external`，body 为 null，同样跳过。

---

### 3. `@Inject` — 在方法体**指定行**注入代码

**含义**：在目标方法体的某一具体行号前后插入语句，不替换原逻辑。

```dart
@Inject("package:example/main.dart", "_MyHomePageState", "-onPluginDemo", lineNum: 108)
@pragma("vm:entry-point")
void myInject() {
  print('injected at line 108');
}
```

**签名格式**：
```
@Inject(importUri, clsName, "-/+methodName", lineNum: N)
```

**工作原理**：  
框架将 `lineNum` 存储为 `N - 1`（注意：**你填的行号会自动减 1**），然后遍历目标方法 body 的 `Block.statements`，找到对应行的语句插入位置，将 hook 语句列表插入。

**行号对应关系**（实测）：

```
你写的 lineNum: N  →  实际存储 N-1  →  插到第 N-1 行的语句之前
```

**局限（最多）**：

| 限制                               | 原因                                                                 |
| ---------------------------------- | -------------------------------------------------------------------- |
| 目标方法必须有 `Block` 类型的 body | 代码中明确判断 `procedure.function.body is Block`，不满足则静默跳过  |
| **箭头函数 `=>` 不支持**           | 箭头函数编译后 body 不是 `Block`，注入被跳过，但 hook 方法体会被清空 |
| **抽象方法不支持**                 | 无 body                                                              |
| lineNum 必须精确                   | 行号偏一行就匹配不上，注入失效                                       |
| 不接受 `PointCut` 参数             | Inject 模式下 hook 方法不接收 pointcut，无法调用原方法               |
| 不支持正则                         | 只能精确匹配 importUri + clsName + methodName                        |
| 第三方库行号会随版本变化           | Flutter SDK 升级后 page.dart 行号可能变动，需要重新校准              |

---

### 4. `@Add` — 向目标类**动态添加方法**

**含义**：在编译期向指定类注入一个新方法（该类原本没有这个方法）。

```dart
@Add("package:example/receiver_test.dart", "Receiver")
@pragma("vm:entry-point")
dynamic addTest(PointCut pointCut, int j, {String? s, int? i}) {
  print('[beike_aspectd]: Add method');
}
```

**签名格式**：
```
@Add(importUri, clsName, {isRegex: false, superCls: ''})
```

**工作原理**：  
遍历所有 Class，找到匹配的类，检查该类中是否已有同名方法，没有则将 hook 方法体注入进去，并把调用转发到 Aspect 类实例。

**`superCls` 参数**：配合正则使用，可以只对继承了特定父类的子类生效，实现批量注入。

**局限**：
- 如果目标类已有同名方法，**静默跳过**（不覆盖）。
- `PointCut` 参数中目前只传了 `sourceInfo`，其他字段（target、args 等）均为 `null`（源码 TODO 注释说明了这是已知限制）。
- 不支持向类添加**字段**或**构造方法**。

---

### 5. `@FieldGet` — 拦截**字段读取**

**含义**：当代码中发生对指定字段的读取（get）操作时，转而调用你的 hook 方法。

```dart
@FieldGet('dart:io', 'Platform', 'isAndroid', true) // true = isStatic
static bool exchange(PointCut pointCut) {
  return true; // 替换返回值
}
```

**签名格式**：
```
@FieldGet(importUri, clsName, fieldName, isStatic)
```

**工作原理**：  
遍历所有 `StaticGet`（静态字段读）和 `InstanceGet`（实例字段读），匹配到目标字段后，将读取表达式替换为调用你的静态 hook 方法，返回值即为"字段值"。

**局限**：
- 只能拦截**读取**，不能拦截写入（没有 FieldSet 对应的注解）。
- 实例字段拦截（`InstanceGet`）目前用的是 `_curLibrary` + `_curClass` 上下文匹配，只能拦截**当前库内**的读取，跨库读取无效。
- 不支持正则（字段名必须精确匹配）。

---

### 6. `@FieldInitializer` — 拦截字段**初始化**（`AopMode.FieldInitializer`）

框架内部存在该模式枚举值，但当前代码库中尚未暴露对应的公开注解类，属于**预留/未完整实现**状态。

---

## 选择建议

```
需要拦截第三方方法？
  ├─ 想获取/修改参数和返回值，且是调用方行为
  │   └─ @Call（调用点少时首选）
  ├─ 想统一替换方法实现（调用方多）
  │   └─ @Execute（效率更高，只改一处）
  ├─ 只想在某行前后插入几行代码（不影响原逻辑）
  │   └─ @Inject（目标必须是 {} 块体方法，行号必须精确）
  ├─ 想读取/替换某个字段的值
  │   └─ @FieldGet
  └─ 想给某个类加方法
      └─ @Add

目标方法是箭头函数 => ？
  └─ 只能用 @Call 或 @Execute，@Inject 无效

目标方法是 abstract / external ？
  └─ 只能用 @Call，拦截调用点
```

---

## 常见陷阱速查

| 现象                                    | 原因                                                                                   |
| --------------------------------------- | -------------------------------------------------------------------------------------- |
| `@Inject` 注入后 hook 方法体变成空 `{}` | 目标是箭头函数，body 不是 Block，注入跳过但方法体仍被清空                              |
| `@Inject` 无任何效果                    | lineNum 不对（记得框架会减 1），或目标是抽象方法                                       |
| `@Execute` 某个方法 hook 不生效         | 方法有泛型类型参数（`typeParameters.isNotEmpty`），被框架跳过                          |
| `@Add` 没有插入方法                     | 目标类已有同名方法，框架静默跳过                                                       |
| `@Call` 正则匹配到了 Aspect 类自身      | 框架会排除 `filteredLibrary == aopItemInfo.aopMember.parent.parent` 的情况，是正常保护 |
| 第三方 SDK 升级后 `@Inject` 失效        | 行号随代码变动，需重新对齐 lineNum                                                     |
