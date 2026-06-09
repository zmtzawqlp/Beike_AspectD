# AopLocation — Widget 创建位置追踪说明

## 概述

`AopLocation` 和 `AopHasCreationLocation` 是一对运行期类型，让你可以在**运行时**查询任意 `Widget` 构造函数被调用时的**源码位置**。主要使用场景是**埋点（事件追踪）**：当用户点击某个按钮时，系统可以自动遍历 Element 树并生成如下格式的点击路径，无需手动给每个 Widget 打标签：

```
HomePage(home)/Column[0]/MyButton[2]
```

该设计参考了 Flutter 官方的 Widget Inspector 机制，但完全独立实现。**新架构下两者可以在同一个 debug 会话中并存，互不冲突**——AOP 用 `aopLocation` 字段，Flutter Inspector 用 `_location` 字段。

> 关于整体架构（`AspectdFlutterTarget` 子类、AOP / stock 共存机制等），见
> [AOP 架构改造说明](AOP架构改造说明.md)。

---

## 整体架构

```
┌──────────────────────────────────────────────────────────────┐
│  Kernel 编译期 Transformer（编译时运行）                        │
│  inner/transformer/plugins/aop/location/                     │
│    track_widget_constructor_locations.dart                   │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ AopWidgetCreatorTracker.transform(program, libs, ...) │   │
│  │  1. 解析 Widget / AopLocation / AopHasCreationLocation│   │
│  │  2. 向每个 Widget 子类注入 aopLocation 字段             │   │
│  │  3. 在每个构造调用点注入位置信息                         │   │
│  │     (file / line / column / name / ownerImportUri)    │   │
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

`AspectdFlutterTarget` 在 `performPreConstantEvaluationTransformations` 钩子里调用
`AopWrapperTransformer.transformWidgetCreator(program)`，后者再委托给本节描述的
`WidgetCreatorTracker.transform(program, program.libraries, null)`。这一步必须在
**常量评估之前**完成，这样新生成的 `ConstConstructorInvocation` 才能被折叠成
kernel `Constant`。

紧接着 `super.performPreConstantEvaluationTransformations(...)` 跑 stock tracker
（仅当 `flags.trackWidgetCreation` 为 true 时），把上游 `_HasCreationLocation` /
`_location` 注入也做掉。AOP 和 stock 各自独立，两个 transformer 互不干扰。

### 第一步：类解析（`_resolveFlutterClasses`）

Tracker 遍历所有 Library，查找三个关键的 kernel 类：

| 查找来源                                              | kernel 类名              |
| ----------------------------------------------------- | ------------------------ |
| `package:flutter/src/widgets/framework.dart`          | `Widget`                 |
| `package:beike_aspectd/src/plugins/aop/location.dart` | `AopHasCreationLocation` |
| `package:beike_aspectd/src/plugins/aop/location.dart` | `AopLocation`            |

使用项目自己的 `location.dart` 而非 Flutter 内部的 `widget_inspector.dart` 是为了
避免和 Flutter Inspector 共用接口/字段类型，这样两个 tracker 才能并存。

### 第二步：Widget 类改造（`_transformClassImplementingWidget`）

对每一个**直接实现 Widget 但不继承自另一个 Widget 子类**的类（即继承链中第一个接触到 Widget 的类），Tracker 会：

1. 添加 `aopLocation` 字段，类型为 `AopLocation?`。
2. 把类的 `implementedTypes` 加上 `AopHasCreationLocation`。
3. 向该类的**每个构造函数**增加一个内部命名参数
   `$creationLocationAopd_0dea112b090073317d4`，类型 `AopLocation?`。
4. 在构造函数体中将该参数赋值给 `aopLocation` 字段。

这与 Flutter Inspector 的处理逻辑结构完全一致，但所有 kernel 标识符独立：

| 标识符           | Stock                            | AOP                                            |
| ---------------- | -------------------------------- | ---------------------------------------------- |
| 命名参数         | `$creationLocationd_…`           | **`$creationLocationAopd_…`**                  |
| Widget 上的字段  | `_location`                      | **`aopLocation`**                              |
| 标记接口         | `_HasCreationLocation`（私有）   | **`AopHasCreationLocation`**（公开）           |
| 位置类           | `_Location`（私有）              | **`AopLocation`**（公开）                      |

四个标识符全独立后，AOP tracker 和 stock tracker 可以串行跑（AOP 先、stock 后），
各自往同一个构造函数里加自己的字段和参数互不冲突，去重检查（`clazz.fields.any`、
`_hasNamedParameter`）也基于自己的常量，不会误判。

### 第三步：调用点注入（`_WidgetCallSiteTransformer`）

每一个产生 Widget 子类实例的 `ConstructorInvocation` 和 `StaticInvocation`
（工厂构造函数或 `@widgetFactory` 扩展方法），都会被自动注入一个额外的命名参数：

```dart
// 你写的源码
Text('hello')

// 经过 AOP Tracker 之后（kernel 层）
Text('hello',
  $creationLocationAopd_0dea112b090073317d4: const AopLocation(
    file:           'file:///…/my_page.dart',
    line:           42,
    column:         10,
    name:           'Text',
    ownerImportUri: 'package:flutter/src/widgets/basic.dart',
  ),
)

// 如果同时开 --track-widget-creation，stock tracker 还会再加一个：
Text('hello',
  $creationLocationAopd_0dea112b090073317d4: const AopLocation(...),
  $creationLocationd_0dea112b090073317d4:    const _Location(...),
)
```

`ownerImportUri` 是相比 Flutter 官方 Inspector 新增的字段，存储的是 **Widget 类的
定义库**（而非调用处所在库）。这使得运行时无需解析 `file` 路径字符串，就能判断
某个 Widget 是来自 Flutter SDK、第三方包、还是当前业务代码。

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

`aop_example/lib/aop/features/click_tracking/click_path_builder.dart` 展示了一个完整
的生产级集成方案：

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

这保证了 Flutter SDK 的 Padding、Column 等基础组件会被**静默跳过**，最终点击路径里
只包含业务层自己的 Widget。

---

## 与 Flutter Inspector 的并存

### 各种场景下 AOP / stock 字段是否注入

| 场景                                                              | AOP 字段        | stock 字段     |
| ----------------------------------------------------------------- | --------------- | -------------- |
| `flutter build`（默认不带 `--track-widget-creation`）              | ✅ aopLocation  | ❌ 不注入       |
| `flutter run --debug` / 任何带 `--track-widget-creation` 的编译     | ✅ aopLocation  | ✅ \_location  |

### 为什么 hot reload 时 AOP 字段不会"丢失"或"退化"

旧架构里，AOP transformer 是 push 进 `FlutterTarget._flutterProgramTransformers`
**静态列表**的，hot reload 在某些情况下会清空这个列表，导致后续 widget 退回到
stock `_Location`，业务层调用 `aopLocation.isFlutterSdk()` 会失败。

新架构下：

- `AopWrapperTransformer` 实例直接绑在 `AspectdFlutterTarget` 实例上。
- target 实例由 `IncrementalCompiler` 持有，跨整个编译生命周期存活。
- AOP transformer 不再依赖任何静态列表，hot reload 不会丢。

如果重启后仍然遇到 hot reload 报错（比如 `NoSuchMethodError` 找不到带
`AopLocation?` 类型的构造函数参数），属于 **build cache 残留**问题：

```
NoSuchMethodError: No constructor 'StatelessWidget.' with matching arguments …
Found: new StatelessWidget.({Key? key, AopLocation? $creationLocationd_xxx})
                                       ^^^^^^^^^^^^   ^^^^^^^^^^^^^^^^^^^^^^^^
                                       AOP 类型      但参数名是旧 AOP tracker 名字
```

这种"AOP 类型 + 旧参数名"组合**只能由改名前的 AOP tracker 注入**。修复方法：

```bash
# 1. 完全 kill 所有跑着的 flutter run / dart 进程（包括 IDE 里那个）
# 2. 清掉所有 build cache
cd <your_project>
flutter clean
rm -rf .dart_tool/flutter_build build
flutter pub get
# 3. 重新冷启动
flutter run
```

---

## 相关文件索引

| 文件                                                                             | 职责                                                                                            |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `lib/src/plugins/aop/location.dart`                                              | 运行期公开类型（`AopLocation`、`AopHasCreationLocation`、`AopLocationE`）                         |
| `lib/aspectd.dart`                                                               | 重新导出 `location.dart`，使用方只需一个 import                                                   |
| `inner/transformer/plugins/aop/location/track_widget_constructor_locations.dart` | Kernel Transformer：改造 Widget 构造函数并注入调用点位置；与上游 `pkg/kernel` 版本仅在 4 处常量/查找路径上不同 |
| `inner/transformer/plugins/aop/aop_transformer_wrapper.dart`                     | 把 widget tracker 包装成 Phase 1（`transformWidgetCreator`），AOP 主转换打包成 Phase 2（`transform`）  |
| `inner/transformer/plugins/aop/aop_flutter_target.dart`                          | `AspectdFlutterTarget` 子类 + `installAspectdFlutterTarget()`，把两阶段钩子接进 kernel pipeline   |
| `aop_example/lib/aop/features/click_tracking/click_path_builder.dart`            | 使用示例：基于 `AopHasCreationLocation` 实现点击路径埋点                                          |
