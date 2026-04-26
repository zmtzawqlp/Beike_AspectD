# AopLocation — Widget 创建位置追踪说明

## 概述

`AopLocation` 和 `AopHasCreationLocation` 是一对运行期类型，让你可以在**运行时**查询任意 `Widget` 构造函数被调用时的**源码位置**。主要使用场景是**埋点（事件追踪）**：当用户点击某个按钮时，系统可以自动遍历 Element 树并生成如下格式的点击路径，无需手动给每个 Widget 打标签：

```
HomePage(home)/Column[0]/MyButton[2]
```

该设计参考了 Flutter 官方的 Widget Inspector 机制，但完全独立实现，两者可以在同一个 debug 会话中并存，互不冲突。

---

## 整体架构

```
┌──────────────────────────────────────────────────────────────┐
│  Kernel 编译期 Transformer（编译时运行）                        │
│  inner/transformer/plugins/aop/location/                     │
│    track_widget_constructor_locations.dart                   │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ AopWidgetCreatorTracker.transform(program, libs, ...)  │   │
│  │  1. 解析 Widget / AopLocation / AopHasCreationLocation  │  │
│  │  2. 向每个 Widget 子类注入 aopLocation 字段              │   │
│  │  3. 在每个构造调用点注入位置信息                          │   │
│  │     (file / line / column / name / ownerImportUri)     │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
             │  编译产物 app.dill
             ▼
┌──────────────────────────────────────────────────────────────┐
│  运行期 API（lib/src/plugins/aop/location.dart）               │
│                                                              │
│  abstract class AopHasCreationLocation {                     │
│    AopLocation get aopLocation;                              │
│  }                                                           │
│                                                              │
│  class AopLocation {                                         │
│    final String  file;           // 源文件绝对路径             │
│    final int     line;           // 行号                      │
│    final int     column;         // 列号                      │
│    final String? name;           // Widget 类名               │
│    final String? ownerImportUri; // 类所在库的 package URI     │
│    bool isFlutterSdk()  { … }    // 是否属于 Flutter SDK？     │
│  }                                                           │
│                                                              │
│  extension AopLocationE on AopLocation {                     │
│    bool isProjectRoot() { … }    // 是否属于当前业务包？        │
│  }                                                           │
└──────────────────────────────────────────────────────────────┘
```

---

## inner transformer 做了什么

### 入口

`inner/transformer/plugins/aop/aop_transformer_wrapper.dart` 中的
`AopWrapperTransformer.transform()` 是每次编译程序时最先被调用的 transform 方法。
现在它的第一步就是：

```dart
_aopWidgetCreatorTracker.transform(program, program.libraries, null);
```

位置追踪 pass 在所有 AOP 注解变换**之前**运行，保证后续变换能正常拿到位置字段。

---

### 第一步：类解析（`_resolveFlutterClasses`）

Tracker 遍历所有 Library，查找三个关键的 kernel 类：

| 查找来源                                              | kernel 类名              |
| ----------------------------------------------------- | ------------------------ |
| `package:flutter/src/widgets/framework.dart`          | `Widget`                 |
| `package:beike_aspectd/src/plugins/aop/location.dart` | `AopHasCreationLocation` |
| `package:beike_aspectd/src/plugins/aop/location.dart` | `AopLocation`            |

使用项目自己的 `location.dart` 而非 Flutter 内部的 `widget_inspector.dart`，
是为了避免命名冲突（详见下文）。

---

### 第二步：Widget 类改造（`_transformClassImplementingWidget`）

对每一个**直接实现 Widget 但不继承自另一个 Widget 子类**的类（即继承链中第一个接触到 Widget 的类），Transformer 会：

1. 添加 `aopLocation` 字段，类型为 `AopLocation`。
2. 向该类的**每个构造函数**增加一个内部命名参数
   `$creationLocationd_0dea112b090073317d4`。
3. 在构造函数体中将该参数赋值给 `aopLocation` 字段。

这与 Flutter Inspector 的处理逻辑相同，但使用的是 AOP 定义的类型。

---

### 第三步：调用点注入（`_WidgetCallSiteTransformer`）

每一个产生 Widget 子类实例的 `ConstructorInvocation` 和 `StaticInvocation`
（工厂构造函数或 `@widgetFactory` 扩展方法），都会被自动注入一个额外的命名参数：

```dart
// 你写的源码
Text('hello')

// 经过 Transformer 之后（kernel 层）
Text('hello',
  $creationLocationd_0dea112b090073317d4: const AopLocation(
    file:           'file:///…/my_page.dart',
    line:           42,
    column:         10,
    name:           'Text',
    ownerImportUri: 'package:flutter/src/widgets/basic.dart',
  ),
)
```

`ownerImportUri` 是相比 Flutter 官方 Inspector 新增的字段，它存储的是**Widget 类的定义库**（而非调用处所在库）。这使得运行时无需解析 `file` 路径字符串，就能判断某个 Widget 是来自 Flutter SDK、第三方包，还是当前业务代码。

---

### 为什么必须重命名（命名冲突问题）

Flutter 官方 Inspector 的 transformer（仅在 `--track-widget-creation` 模式下生效）使用了以下私有符号：

| 符号            | 官方名称                       |
| --------------- | ------------------------------ |
| 接口            | `_HasCreationLocation`（私有） |
| 位置类          | `_Location`（私有）            |
| Widget 上的字段 | `_location`（私有）            |

如果 Beike-AspectD 复用这些名称，热重载时 Flutter 引擎会检测到字段重复定义并抛出错误。
因此 Tracker 统一使用独立的公开名称：

| 符号            | AOP 名称                 |
| --------------- | ------------------------ |
| 接口            | `AopHasCreationLocation` |
| 位置类          | `AopLocation`            |
| Widget 上的字段 | `aopLocation`            |

这样 Flutter Inspector 和 Beike-AspectD 可以在同一个 debug session 中同时运行。

---

### Hot reload 之后为什么会变成 `_Location`

这个问题并不是运行期 API 本身的问题，而是**增量编译链路里 transformer 丢失或混跑**导致的。

在 Flutter debug 模式下，官方 `FlutterTarget` 在 `trackWidgetCreation` 开启时，会默认执行官方的 `WidgetCreatorTracker`。它注入的是：

- `_HasCreationLocation`
- `_Location`
- `_location`

而 Beike-AspectD 的位置追踪 pass 注入的是：

- `AopHasCreationLocation`
- `AopLocation`
- `aopLocation`

如果 full compile 时跑的是 AOP tracker，但 hot reload 的增量编译阶段把自定义 transformer 清掉了，后续重新生成的 Widget 就可能退回到官方 `_Location` 方案。此时页面树里会同时存在两类对象：

- 旧对象：`AopLocation`
- 新对象：`_Location`

一旦业务代码把 `aopLocation` 当成 `AopLocation` 去调用 `isFlutterSdk()` 或 `isProjectRoot()`，就会出现下面这种报错：

```dart
NoSuchMethodError: Class '_Location' has no instance method 'isFlutterSdk'
```

---

### Hot reload 修复点

当前保留的修复点主要有两部分。

#### 1. `recompileDelta()` 不再直接清空 AOP transformer

文件：`inner/flutter_frontend_server/server.dart`

核心修改：

```dart
@override
Future<void> recompileDelta({String? entryPoint, bool recompileRestart = false}) async {
  final List<FlutterProgramTransformer> transformers =
      FlutterTarget.flutterProgramTransformers;
  // 解决 reload 直接 clear 导致 AOP transformer 丢失问题
  // 比如导致 AopHasCreationLocation 的 aopLocation 变成 _Location
  if (aopTransform == true) {
    if (!transformers.contains(aspectdAopTransformer)) {
      transformers.add(aspectdAopTransformer);
    }
  } else {
    transformers.clear();
  }

  return _compiler.recompileDelta(
    entryPoint: entryPoint,
    recompileRestart: recompileRestart,
  );
}
```

这一步的作用是：**增量编译时持续保留 AOP 自定义 transformer**，避免首次编译走 `AopLocation`、热重载后又回退成 `_Location`。

#### 2. 示例侧增加运行时防御（可选但建议保留）

在 `aop_example/lib/aop/hook_handler/click.dart` 里，对 `aopLocation` 先做运行时类型判断。这样即使某些旧对象还残留 `_Location`，也不会在点击路径收集阶段直接崩溃，而是跳过该节点。

---

## 运行期 API

### `AopLocation`

```dart
class AopLocation {
  final String  file;           // 源文件 URI 或绝对路径
  final int     line;           // 1-based 行号
  final int     column;         // 1-based 列号
  final String? name;           // Widget 类名，例如 "Text"
  final String? ownerImportUri; // 例如 "package:flutter/src/widgets/basic.dart"

  /// 判断该 Widget 是否定义在 Flutter SDK 内部
  bool isFlutterSdk();
}
```

### `AopLocationE` 扩展

```dart
extension AopLocationE on AopLocation {
  /// 判断该 Widget 是否属于当前业务包（项目根包）
  ///
  /// 通过 --dart-define=AOP_PACKAGE_NAME=<包名> 控制
  bool isProjectRoot();
}
```

`isProjectRoot()` 会过滤掉以下情况，返回 `false`：

- Flutter SDK 的 Widget（`isFlutterSdk()` 为 true）
- pub cache 中的第三方包
- `package:` URI 不以 `package:<your_package>/` 开头的所有库

### `AopHasCreationLocation`

```dart
abstract class AopHasCreationLocation {
  AopLocation get aopLocation;
}
```

经过 Transformer 编译之后，程序中**所有 Widget** 在 kernel 层都实现了这个接口。
运行时可以直接 cast：

```dart
if (widget is AopHasCreationLocation) {
  final AopLocation loc = (widget as AopHasCreationLocation).aopLocation;
  print(loc);
  // AopLocation{file: …, line: 42, column: 10, name: Text, ownerImportUri: package:flutter/…}
}
```

---

## 端到端埋点示例

`aop_example/lib/aop/hook_handler/click.dart` 展示了一个完整的生产级集成方案：

```
用户点击屏幕
   │
   ▼
onHitTestTargetHandleEvent()       ← AOP hook：HitTestTarget.handleEvent
   │  将 RenderObject 和 PointerEvent 存入 _hitTestTargetMap
   ▼
onGestureRecognizerInvokeCallback('onTap')  ← AOP hook：GestureRecognizer
   │
   ▼
_handleClickEvent(renderObject)
   │  1. 通过 renderObject.debugCreator 拿到 Element
   │  2. _addShowInfo()   — 提取可见文本 / 图片 asset 名称
   │  3. _addAncestor()   — 向上遍历祖先，仅保留 isProjectRoot() 的节点
   │  4. 遇到 RouteInfoWidget（页面根节点）或弹框时停止
   │
   ▼
clickInfo.value = "HomePage(home)/Column[0]/MyButton[2] | 提交"
```

`_addAncestor` / `_isLocalElement` 中的核心过滤逻辑：

```dart
bool _isLocalElement(Element element) {
  final Widget widget = element.widget;
  if (widget is AopHasCreationLocation) {
    return (widget as AopHasCreationLocation).aopLocation.isProjectRoot();
  }
  return false;
}
```

这保证了 Flutter SDK 的 Padding、Column 等基础组件会被**静默跳过**，
最终点击路径里只包含业务层自己的 Widget。

---

## 相关文件索引

| 文件                                                                             | 职责                                                                      |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `lib/src/plugins/aop/location.dart`                                              | 运行期公开类型（`AopLocation`、`AopHasCreationLocation`、`AopLocationE`） |
| `lib/aspectd.dart`                                                               | 重新导出 `location.dart`，使用方只需一个 import                           |
| `inner/transformer/plugins/aop/location/track_widget_constructor_locations.dart` | Kernel Transformer：改造 Widget 构造函数并注入调用点位置                  |
| `inner/transformer/plugins/aop/aop_transformer_wrapper.dart`                     | 将 Tracker 作为第一个 transform pass 运行                                 |
| `aop_example/lib/aop/hook_handler/click.dart`                                    | 使用示例：基于 `AopHasCreationLocation` 实现点击路径埋点                  |
