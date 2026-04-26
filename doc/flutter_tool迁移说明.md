# flutter_tool 迁移说明

本文档记录在升级 Flutter 版本时，如何迁移 Beike_AspectD 对 `flutter_tools` 的改造，并重新生成 `flutter_tool.patch`。

## 目标

- 让目标 Flutter 版本继续支持 AOP 编译链路。
- 保持 `aop_config.yaml` 有配置时开启 AOP，无配置时不影响原生编译。
- 产出可复用的 `flutter_tool.patch`。

## 迁移范围

当前改造点包括：

- 新增目录：`packages/flutter_tools/lib/src/aop/`
  - `aop_manager.dart`
  - `aspectd.dart`
  - `hook_factory.dart`
- 修改文件：
  - `packages/flutter_tools/lib/src/compile.dart`
  - `packages/flutter_tools/lib/src/build_system/targets/common.dart`
  - `packages/flutter_tools/lib/src/build_system/targets/web.dart`
  - `packages/flutter_tools/lib/src/commands/build_bundle.dart`

## 迁移步骤

1. 准备目标 Flutter 源码
- 切到目标 Flutter 版本分支或 tag。
- 确保 `packages/flutter_tools` 是干净状态（`git status` 无本地改动）。

2. 迁入 AOP 目录
- 将旧版本中的 `packages/flutter_tools/lib/src/aop/` 整体复制到目标版本同路径。
- 如果目标版本同名 API 发生变化，优先保留目标版本接口，再适配 AOP 逻辑。

3. 迁移 4 个核心补丁点
- `compile.dart`
  - 引入 `aop/aspectd.dart`。
  - 在编译入口调用 `AspectdHook.enableAspectd()`。
  - 当配置存在时追加 `--aop 1` 到 frontend_server 参数。
  - Debug 模式打印 `Debug frontend_server start args: ...`。
- `common.dart`
  - 引入 `../../aop/aspectd.dart`。
  - 在 `KernelSnapshot.build` 前调用 `AspectdHook.enableAspectd()`。
- `web.dart`
  - 引入 `../../aop/aop_manager.dart`。
  - 在 web CFE 编译后调用 `AopManager.hookSnapshotCommand(...)`。
- `build_bundle.dart`
  - 引入 `../aop/aspectd.dart`。
  - 在 `runCommand` 开始执行 `AspectdHook.enableAspectd()`。

4. 处理冲突并完成适配
- 若目标版本方法签名变化（参数新增/删除、返回值变化），按目标版本为准改造调用。
- 若编译命令构造逻辑重构，确保 `--aop 1` 注入时机仍在 frontend_server 启动参数组装阶段。

5. 生成新的 patch
- 在 Flutter 根目录执行（建议仅导出 `flutter_tools` 相关改动）：

```bash
git diff -- packages/flutter_tools/lib/src/aop \
  packages/flutter_tools/lib/src/compile.dart \
  packages/flutter_tools/lib/src/build_system/targets/common.dart \
  packages/flutter_tools/lib/src/build_system/targets/web.dart \
  packages/flutter_tools/lib/src/commands/build_bundle.dart \
  > /path/to/Beike_AspectD/flutter_tool.patch
```

- 如果当前工作区只包含 `flutter_tools` 迁移改动，也可以直接使用：

```bash
git diff --binary --output=flutter_tool.patch
```

- 覆盖仓库中的 `flutter_tool.patch`，并确认 patch 可重复应用。

6. 验证迁移结果
- 在干净 Flutter 源码执行：

```bash
git apply /path/to/Beike_AspectD/flutter_tool.patch
```

- 删除工具缓存并触发重建：

```bash
rm bin/cache/flutter_tools.stamp
flutter --version
```

- 在示例工程验证两种场景：
  - 无 `aop_config.yaml`：编译链路应与原生一致。
  - 有 `aop_config.yaml`：frontend_server 参数应包含 `--aop 1`，AOP 生效。

## 回归检查清单

- `flutter build` / `flutter run` 在 debug、profile、release 至少各验证 1 次。
- `flutter build web` 验证 `AopManager.hookSnapshotCommand` 路径可用。
- Debug 日志能输出 `Debug frontend_server start args:`。
- patch 在目标 Flutter 版本可 `git apply`，且无 `.rej` 文件。

## 常见问题

1. `git apply` 失败
- 原因：目标版本上下文变化。
- 处理：先手工迁移后重新导出 patch，不建议长期保留 reject 文件。

2. `--aop 1` 未注入
- 原因：`AspectdHook.configFileExists()` 返回 false，或参数注入位置被版本重构覆盖。
- 处理：检查 `aop_config.yaml` 路径与 `compile.dart` 参数组装逻辑。

3. 调试时 AOP 不生效
- 处理：参考 `doc/frontend_server参数复制与debug_server修改.md`，确认使用了正确的 frontend_server 启动参数。

## bin 脚本用途说明

详见：[bin脚本用途说明](bin脚本用途说明.md)