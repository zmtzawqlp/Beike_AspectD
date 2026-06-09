# AOP 架构改造说明（2026-06）

本文档记录 Beike_AspectD 在 Flutter 3.44.1 / Dart 3.12.1 上的一次架构重构。
目标是把 AOP 注入点从 `inner/pkg/*` 内部迁出，让 `pkg/*` 完全跟随上游 SDK。

## 旧架构（已废弃）

旧版 AOP 直接修改 `inner/pkg/vm/lib/modular/target/flutter.dart`，向 `FlutterTarget`
里加了一个静态列表 `_flutterProgramTransformers` 和两个钩子：

```dart
abstract class FlutterProgramTransformer {
  void transform(Component, ...);
  void transformWidgetCreator(Component, ...) {}
}

class FlutterTarget extends VmTarget {
  static List<FlutterProgramTransformer> _flutterProgramTransformers = [];

  @override
  void performPreConstantEvaluationTransformations(...) {
    // AOP Phase 1
    for (final t in _flutterProgramTransformers) {
      t.transformWidgetCreator(component, logger: logger);
    }
    super.performPreConstantEvaluationTransformations(...);
    // 跳过 stock tracker 避免 _location / aopLocation 双注入冲突
    if (flags.trackWidgetCreation && _flutterProgramTransformers.isEmpty) {
      _widgetTracker.transform(...);
    }
  }

  @override
  void performModularTransformationsOnLibraries(...) {
    super.performModularTransformationsOnLibraries(...);
    // AOP Phase 2
    for (final t in _flutterProgramTransformers) {
      t.transform(component, logger: logger);
    }
  }
}
```

外层 `inner/flutter_frontend_server/server.dart` 在 `compile()` 第一次调用时把
`AopWrapperTransformer` push 进静态列表，`recompileDelta()` 还要做防御性的
"列表被清空时再插回去"逻辑。

### 旧架构的问题

| 问题 | 说明 |
| --- | --- |
| **强侵入** | 必须修改 `pkg/vm`，每次升级 SDK 都得重新打 patch |
| **跨进程状态** | 静态列表在 incremental 编译 / hot reload 时容易被清空，需要额外补救代码 |
| **参数名撞名** | AOP 和 stock 的 `_creationLocationParameterName` 都是 `$creationLocationd_…`，两个 tracker 不能同时跑，只能二选一 |
| **DevTools 不兼容** | 因为不能共存，AOP 启用时 stock `_location` 字段缺失，DevTools widget inspector 失效 |

## 新架构

新架构有四块要点：

1. **`AspectdFlutterTarget`**：在 AOP 包里写一个 `FlutterTarget` 的子类，自己接管
   两个 transform 钩子，AOP transformer 实例直接绑在 target 实例上。
2. **`installAspectdFlutterTarget()`**：在 `compile()` 第一次调用前替换全局
   `targets['flutter']` builder，让 frontend_server 创建 target 时拿到我们的子类。
3. **参数名独立**：AOP 的 widget tracker 把 `$creationLocationd_…` 改成
   `$creationLocationAopd_…`，stock 与 AOP 完全独立、可共存。
4. **代理 pkg starter**：`inner/flutter_frontend_server/server.dart` 不再自己写
   stdin / 单次编译派发，全部转发给 `package:frontend_server/starter.dart`。

新架构下 `inner/pkg/*` **完全是 SDK 镜像，零修改**。

### 整体数据流

```
flutter run / flutter build
        │
        ▼
flutter_tools.snapshot
        │  注入 --aop 1 + 拼好 frontend_server 启动参数
        ▼
frontend_server_aot.dart.snapshot
   (= inner/flutter_frontend_server/starter.dart 编译产物)
        │
        ▼
inner/flutter_frontend_server/server.dart
   ├─ 给 frontend.argParser 注册 --aop 选项
   ├─ 预先 parse 一次 args，读出 aopEnabled
   ├─ 构造 _FlutterFrontendCompiler(aopTransform: aopEnabled, ...)
   └─ 转发给 package:frontend_server/starter.dart#starter
              │
              ▼
        FrontendCompiler.compile(...)
              │
              ├─ createFrontEndTarget('flutter', ...)
              │      └─ targets['flutter']  ←  我们已替换为 AspectdFlutterTarget builder
              │            └─ AspectdFlutterTarget(flags) 持有 AopWrapperTransformer
              │
              ├─ IncrementalCompiler / one-shot compile
              │
              └─ Phase 1: target.performPreConstantEvaluationTransformations
                            ├─ aop.transformWidgetCreator(component)   // 注 aopLocation
                            └─ super(...)
                                    └─ 若 flags.trackWidgetCreation:
                                         WidgetCreatorTracker.transform   // 注 _location
                  ─────────── 常量评估 ───────────
                 Phase 2: target.performModularTransformationsOnLibraries
                            ├─ super(...)
                            └─ aop.transform(component)                  // AOP 主转换
```

### 关键文件

| 文件 | 作用 |
| --- | --- |
| `inner/transformer/plugins/aop/aop_flutter_target.dart` | `AspectdFlutterTarget` + `installAspectdFlutterTarget()` |
| `inner/transformer/plugins/aop/aop_transformer_wrapper.dart` | `AopWrapperTransformer`，含 `transformWidgetCreator()`/`transform()` 两阶段方法（不再 extends `FlutterProgramTransformer`） |
| `inner/transformer/plugins/aop/location/track_widget_constructor_locations.dart` | AOP 专属 widget tracker（参数名 `$creationLocationAopd_…`、字段 `aopLocation`、接口 `AopHasCreationLocation`） |
| `inner/flutter_frontend_server/server.dart` | 包装层：注册 `--aop` → 预 parse → 构造 compiler → 转发 pkg starter |
| `inner/pkg/vm/lib/modular/target/flutter.dart` | **完全 pristine SDK 版本**，0 修改 |

### 关键代码片段

#### 1. AspectdFlutterTarget 子类

```dart
class AspectdFlutterTarget extends FlutterTarget {
  AspectdFlutterTarget(TargetFlags flags) : super(flags);

  final AopWrapperTransformer _aopTransformer = AopWrapperTransformer();

  @override
  void performPreConstantEvaluationTransformations(...) {
    // Phase 1：必须在常量评估之前注入 widget creator
    _aopTransformer.transformWidgetCreator(component, logger: logger);
    super.performPreConstantEvaluationTransformations(...);
    // super 内部会按 flags.trackWidgetCreation 决定是否跑 stock tracker
    // AOP 和 stock 现在用独立的参数名/字段名，两边都跑没问题
  }

  @override
  void performModularTransformationsOnLibraries(...) {
    super.performModularTransformationsOnLibraries(...);
    // Phase 2：必须在常量评估之后跑 AOP 主转换
    _aopTransformer.transform(component, logger: logger);
  }
}

void installAspectdFlutterTarget() {
  installAdditionalTargets();           // pkg/vm 自带的注册函数（先注册 vanilla）
  targets['flutter'] = (TargetFlags flags) => AspectdFlutterTarget(flags);
}
```

#### 2. 包装层入口

```dart
Future<int> starter(List<String> args, {...}) async {
  _registerAopOption();                  // 给 frontend.argParser 加 --aop

  final options = frontend.argParser.parse(args);
  final aopEnabled = options['aop']?.toString() == '1';
  final deleteToStringPackageUris = ...;

  compiler ??= _FlutterFrontendCompiler(
    output,
    transformer: ToStringTransformer(transformer, deleteToStringPackageUris),
    unsafePackageSerialization: options['unsafe-package-serialization'],
    aopTransform: aopEnabled,
  );

  return frontend_starter.starter(args, compiler: compiler, input: input, output: output);
}
```

`_FlutterFrontendCompiler.compile()` 在第一次被调用时执行
`installAspectdFlutterTarget()`，之后 `FrontendCompiler.compile()` 内部
`createFrontEndTarget('flutter', flags)` 拿到的就是我们的子类。

## AOP / Stock 共存

AOP 和上游 stock 的 widget tracker 在四个 kernel 标识符上**完全独立**：

| 维度 | Stock | AOP |
| --- | --- | --- |
| 命名参数 | `$creationLocationd_0dea112b090073317d4` | `$creationLocationAopd_0dea112b090073317d4` |
| Widget 上的字段 | `_location` | `aopLocation` |
| 标记接口 | `_HasCreationLocation`（`flutter/src/widgets/widget_inspector.dart`） | `AopHasCreationLocation`（`beike_aspectd/src/plugins/aop/location.dart`） |
| 位置数据类 | `_Location` | `AopLocation` |

### 四种场景下的行为

| 场景 | trackWidgetCreation | AOP 字段 | stock 字段 |
| --- | --- | --- | --- |
| `flutter build`（不传 `--track-widget-creation`） | false | ✅ aopLocation 注入 | ❌ 不注入 |
| `flutter run --debug` / `flutter run --profile` | true | ✅ aopLocation 注入 | ✅ \_location 注入 |
| 不开 AOP 但要 widget inspector | true | ❌（不注册 AspectdFlutterTarget） | ✅ \_location 注入 |
| 既不开 AOP 也不 trackWidgetCreation | false | ❌ | ❌ |

也就是说，新架构下：

- **打 release 包**只注入 AOP 字段，体积和老架构相当。
- **debug / hot reload** AOP 和 DevTools 同时工作，widget inspector 看 `_location`，
  AOP 业务代码看 `aopLocation`，互不干扰。
- **业务运行时代码**只通过 `widget is AopHasCreationLocation` + `widget.aopLocation`
  读取数据，从不依赖参数名，所以参数改名对运行时透明。

### 共存示例：StatelessWidget 改造后的构造函数

```dart
abstract class StatelessWidget extends Widget {
  const StatelessWidget({
    Key? key,
    AopLocation? $creationLocationAopd_0dea112b090073317d4,   // AOP 注入
    _Location?   $creationLocationd_0dea112b090073317d4,      // stock 注入
  }) : super(
         key: key,
         $creationLocationAopd_0dea112b090073317d4: $creationLocationAopd_0dea112b090073317d4,
         $creationLocationd_0dea112b090073317d4: $creationLocationd_0dea112b090073317d4,
       );
}
```

每个 widget 构造调用同时多两个命名参数，分别赋值给两个独立的字段。

## 升级 SDK 时的工作量对比

| 步骤 | 旧架构 | 新架构 |
| --- | --- | --- |
| 替换 `inner/pkg/*` | 整包替换 + 手工保留 `flutter.dart` 里的 `_flutterProgramTransformers` 改造 | **整包替换，0 修改** |
| 修复 inner 内部 API 适配 | 必做 | 必做（`AspectdFlutterTarget` 跟随 `FlutterTarget` 签名变化） |
| 同步 `track_widget_constructor_locations.dart` 上游变化 | 必做 | 必做（仅保留 4 个 AOP 专属常量与类查找逻辑） |
| 重新生成 snapshot | 必做 | 必做 |
| 重新生成 `flutter_tools.patch` | 视情况而定 | 不变 |

## 验证 AOP 转换正确性

```bash
# 1. dump dill 文件
dart inner/pkg/vm/bin/dump_kernel.dart \
  aop_example/.dart_tool/flutter_build/<hash>/app.dill \
  /tmp/out.dill.txt

# 2. 检查关键 AOP 标记数量
for k in aopLocation ClickAspect PointCut::proceed PerformanceAspect; do
  printf "%-30s %s\n" "$k" "$(grep -c "$k" /tmp/out.dill.txt)"
done

# 3. 检查 AOP / stock 共存时的双字段
for k in '$creationLocationAopd_' '$creationLocationd_' aopLocation _location \
         AopHasCreationLocation _HasCreationLocation; do
  printf "%-30s %s\n" "$k" "$(grep -cF "$k" /tmp/out.dill.txt)"
done
```

`aop_example` 的参考值（Flutter 3.44.1）：

| 标记 | 数量 |
| --- | --- |
| `aopLocation`（字段） | 318 |
| `ClickAspect` | 9 |
| `PointCut::proceed` | 13 |
| `PerformanceAspect` | 10 |
| `$creationLocationAopd_`（参数 / 实参） | 4206 |

如果是 `flutter run --debug`（带 `--track-widget-creation`），还会看到：

| 标记 | 数量 |
| --- | --- |
| `_location`（字段） | 386 |
| `$creationLocationd_`（参数 / 实参） | 4206 |
| `_HasCreationLocation` | 9 |

## 注意事项

- 升级 snapshot 后**必须 `flutter clean` + `rm -rf <project>/.dart_tool/flutter_build`
  并重启所有 `flutter run` / `dart` 进程**。否则 incremental compiler 用
  `--initialize-from-dill` 指向旧 dill，新代码用新参数名调用旧 framework 类签名，
  会出现类似下面这种 NSM：

  ```
  NoSuchMethodError: No constructor 'StatelessWidget.' with matching arguments declared …
  Found: new StatelessWidget.({Key? key, AopLocation? $creationLocationd_xxx})
  ```

  错误里出现"AOP 类型 `AopLocation` + 旧参数名 `$creationLocationd_`"这种组合，
  100% 是 cache 残留 + 进程未重启，按上面的方式清理即可。

- `inner/transformer/plugins/aop/location/track_widget_constructor_locations.dart`
  与 SDK 版的 `pkg/kernel/lib/transformations/track_widget_constructor_locations.dart`
  内容**几乎完全一致**，diff 只允许有：
  - `_creationLocationParameterName` 常量（必须含 `Aopd_`）
  - `_locationFieldName` 常量（`aopLocation`）
  - 类查找路径（`beike_aspectd/...` 而非 `flutter/src/widgets/widget_inspector.dart`）
  - `_constructLocation` 多注入 `ownerImportUri` 命名参数

  其余差异都应被同步回去。
