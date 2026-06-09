# pkg 迁移说明

本文档记录 Beike_AspectD 在升级到新 Flutter/Dart SDK 时，`inner/pkg` 的迁移流程。

> **重要变更（2026-06）：** AOP 改造已经从 `inner/pkg/` 内迁出。`inner/pkg/*` 现在
> 是**纯 SDK 镜像**——里面不再包含任何 AOP 相关的修改。详情见 [AOP 架构改造说明](AOP架构改造说明.md)。

## 目标

- 对齐目标 Flutter 对应的 Dart SDK 版本。
- 通过 `inner/pubspec.yaml` 的 `dependency_overrides` 把本地 `inner/pkg/*` 当作上游
  SDK 源码的快照固定下来，方便我们继承 / 引用其中的类。
- 自定义打包 `frontend_server_aot.dart.snapshot` 和 `starter.snapshot`，将其塞进
  Flutter SDK 缓存目录覆盖默认产物。

## 为什么还要保留 `inner/pkg/`

AOP 不再向 `pkg/*` 内塞代码，但仍然需要这些 pkg 作为 **import 来源**：

| 使用方                                                       | 依赖 pkg 提供的能力                                                         |
| ------------------------------------------------------------ | --------------------------------------------------------------------------- |
| `inner/transformer/plugins/aop/aop_flutter_target.dart`      | 继承 `FlutterTarget`、覆盖 `targets['flutter']`、`TargetFlags` 等           |
| `inner/transformer/plugins/aop/aop_transformer_wrapper.dart` | 引用 `Component`/`Library` 等 kernel AST                                    |
| `inner/flutter_frontend_server/server.dart`                  | 实现 `CompilerInterface`、转交 `package:frontend_server/starter.dart` |
| `inner/tool/starter.dart`                                    | 离线 dill 后处理时引用 kernel binary IO                                     |

也就是说：**pkg 保留是为了"用类"，不是为了"改类"**。

## 迁移步骤

### 1. 确认目标 SDK 版本

- 查 `path_to_flutter/bin/cache/dart-sdk/revision`，得到该 Flutter 版本对应的 Dart
  SDK commit。
- 后续所有 `pkg/*` 都从该 commit 复制。

### 2. 替换 `inner/pkg/`

不再需要手工保留 `pkg/*` 内的 patch。直接整包替换：

1. 用目标 Dart SDK 的对应路径覆盖 `inner/pkg/<package>`（例如：用 SDK 里的
   `pkg/vm/` 覆盖 `inner/pkg/vm/`）。
2. 至少需要替换：

   - `pkg/vm`
   - `pkg/frontend_server`
   - `pkg/kernel`
   - `pkg/front_end`
   - `pkg/_fe_analyzer_shared`
   - `pkg/dev_compiler`
   - `pkg/build_integration`
   - `pkg/_js_interop_checks`
   - `pkg/compiler`
   - `pkg/dart2wasm` / `pkg/wasm_builder`（如目标 SDK 有）
   - `pkg/js_ast`、`pkg/js_runtime`、`pkg/js_shared`
   - `pkg/shell_arg_splitter`（如目标 SDK 有）

   完整列表以 `inner/pubspec.yaml` 的 `dependency_overrides` 为准。

3. **不要再手工保留 `pkg/vm/lib/modular/target/flutter.dart` 里的
   `FlutterProgramTransformer` 静态列表修改。** 新架构通过子类 + 注册替换实现，
   不再要求 `pkg/vm` 有任何修改。

### 3. 配置 `dependency_overrides`

[inner/pubspec.yaml](../inner/pubspec.yaml) 已经把所有需要本地 pkg 的库都列出来了。
新增 / 删除 pkg 时同步增删。

### 4. 在 `inner` 执行 `pub get`

```bash
cd inner
flutter pub get   # 或 dart pub get
```

如果出现缺失依赖：

- 把目标 SDK 里对应 `pkg/*` 整包复制进 `inner/pkg/`。
- 在 `dependency_overrides` 里加上同名映射。
- 重新 `pub get`，重复直到无报错。

### 5. 修复 inner 内部的 API 兼容报错

由于 SDK 升级，inner 自己的代码（不是 pkg）可能有 API 适配问题：

- `inner/transformer/plugins/aop/**` —— AOP 各个 transformer 引用了 kernel AST，
  类的字段或构造函数变化时需要适配。
- `inner/transformer/plugins/aop/location/track_widget_constructor_locations.dart`
  —— 这是 AOP 自己的 widget tracker，是从 `pkg/kernel/lib/transformations/`
  里那份**复制改造**而来的，**新版本 pkg 替换后需要把这份的逻辑同步上来**：
  从 `inner/pkg/kernel/lib/transformations/track_widget_constructor_locations.dart`
  把上游差异 merge 回 AOP 那份，但保留以下 AOP 专属定制：

  | 常量 / 类                       | AOP 端取值                                                       |
  | ------------------------------- | ---------------------------------------------------------------- |
  | `_creationLocationParameterName` | `r'$creationLocationAopd_0dea112b090073317d4'`                   |
  | `_locationFieldName`             | `r'aopLocation'`                                                 |
  | 标记接口类                       | `AopHasCreationLocation`（在 `package:beike_aspectd/...`）       |
  | 位置数据类                       | `AopLocation`（同上）                                            |
  | 类查找路径                       | `package:beike_aspectd/src/plugins/aop/location.dart`            |
  | `_constructLocation`             | 多注入一个 `ownerImportUri` 命名参数                             |

  这两份文件的 diff 应该**只剩这些 AOP 专属差异**，其它都跟随上游。

- `inner/flutter_frontend_server/server.dart` —— 如果上游 `CompilerInterface`
  方法签名变化，需要同步覆盖。

### 6. 验证产物

```bash
cd inner

# 1) 重新生成 starter.snapshot 和 frontend_server_aot.dart.snapshot
dart snapshot.dart

# 2) 把新 snapshot 部署进 Flutter SDK 缓存目录覆盖默认值
SDK_ROOT=/path/to/flutter
cp flutter_frontend_server/frontend_server_aot.dart.snapshot \
   $SDK_ROOT/bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot
cp flutter_frontend_server/frontend_server_aot.dart.snapshot \
   $SDK_ROOT/bin/cache/artifacts/engine/<host_platform>/frontend_server_aot.dart.snapshot

# 3) 在 aop_example 里完整跑一遍
cd ../aop_example
flutter clean
rm -rf .dart_tool/flutter_build build
flutter pub get
flutter build ios --debug --no-codesign --simulator   # 或 apk debug

# 4) dump dill 验证 AOP 转换数量
dart ../inner/pkg/vm/bin/dump_kernel.dart \
  .dart_tool/flutter_build/<hash>/app.dill /tmp/out.dill.txt
grep -c 'aopLocation\|ClickAspect\|PointCut::proceed' /tmp/out.dill.txt
```

## 经验建议

- **完全不需要在 `pkg/*` 里留 patch。** 想"打补丁"时停下来想想能否用子类、装饰器
  或注册替换来实现。
- 每次替换 pkg 后立刻 `pub get`，问题不要积压。
- 升级 SDK 后 `pkg/kernel/lib/transformations/track_widget_constructor_locations.dart`
  里的逻辑变化一定要 merge 回 AOP 那份。两份文件 diff 只允许 AOP 专属改动存在。
- 替换 pkg 后只需要重新生成 snapshot，不需要重新生成 `flutter_tools.patch`。
