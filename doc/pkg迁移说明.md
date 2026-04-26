# pkg 迁移说明

本文档记录 Beike_AspectD 在升级到新 Flutter/Dart SDK 时，`inner/pkg` 的迁移流程。

## 目标

- 对齐目标 Flutter 对应的 Dart SDK 版本。
- 保留并适配自定义能力：
  - `FlutterProgramTransformer` 改造（位于 `pkg/vm` 相关链路）。
  - 自定义打包的 `frontend_server_aot.dart.snapshot`（位于 `frontend_server` 相关链路）。
- 通过 `inner/pubspec.yaml` 的 `dependency_overrides` 固定本地 `pkg/*` 引用，直到 `pub get` 完整通过。

## 迁移步骤

1. 确认目标 SDK 版本
- 在目标 Flutter 中确认对应 Dart SDK 版本与 revision。
- 以该版本的 Dart SDK 源码作为迁移基线。

2. 清理旧 `pkg`
- 删除 `inner/pkg` 中旧的迁移内容（按你的实际策略可整包清理或定向清理）。
- 避免旧版本残留导致 API/依赖错配。

3. 先迁入必要最小集合
- 优先迁入最小可运行集合（通常至少包含）：
  - `pkg/vm`
  - `pkg/frontend_server`
- 在迁入后先完成两处核心改造：
  - `FlutterProgramTransformer` 的定制修改。
  - 生成/替换自定义 `frontend_server_aot.dart.snapshot` 的相关逻辑。

4. 配置 `dependency_overrides`
- 在 [inner/pubspec.yaml](../inner/pubspec.yaml) 的 `dependency_overrides` 中，将已迁入的库指向本地 `pkg/*` 路径。
- 示例（按实际已迁入库增减）：

```yaml
dependency_overrides:
  frontend_server:
    path: pkg/frontend_server
  vm:
    path: pkg/vm
  kernel:
    path: pkg/kernel
```

5. 在 `inner` 执行 `pub get`
- 进入 `inner` 目录执行依赖解析。
- 如果出现缺失依赖/未引用包：
  - 从目标 Dart SDK 继续复制对应 `pkg/*` 到 `inner/pkg/*`。
  - 在 `dependency_overrides` 增加该库映射。
- 重复该过程，直到 `pub get` 无错误。

6. 修复代码编译错误
- 基于当前 SDK 版本，修复 `inner` 内部由于 API 变化导致的编译报错。
- 重点关注：`vm`、`front_end`、`frontend_server`、`kernel` 等 AOP 改造链路涉及模块。

7. 验证产物
- 重新生成快照并验证：
  - `starter.snapshot`
  - `frontend_server_aot.dart.snapshot`
- 在示例工程或业务工程中执行编译，确认 AOP 链路生效。

## 经验建议

- 采用“最小集合先迁移 + 缺什么补什么”的策略，避免一次性大规模复制导致排错困难。
- 每次补库后立即 `pub get`，尽早暴露问题。
- `dependency_overrides` 必须与 `inner/pkg` 的实际内容保持一致。
- 迁移完成后，建议保留一次变更清单（新增/修改的 `pkg` 与 patch 点），便于后续 SDK 升级复用。
