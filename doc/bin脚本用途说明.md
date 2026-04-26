# bin 脚本用途说明

本文档说明 Beike_AspectD 仓库根目录 `bin/` 下 3 个脚本的职责与使用方式。

## 适用场景

- 升级 Flutter / flutter_tools 后，验证 AOP 编译链路是否正常。
- 调试 frontend_server 源码行为。
- 检查 `app.dill` 中 Hook 是否生效。
- 重新生成或验证 snapshot 产物。

## 脚本一览

| 脚本                    | 主要用途                                  | 何时运行                              |
| ----------------------- | ----------------------------------------- | ------------------------------------- |
| `bin/debug_server.dart` | 源码方式启动 frontend_server 调试入口     | 需要调试 `inner/` 代码时              |
| `bin/dump.dart`         | 将 `app.dill` 导出为可读文本              | 需要验证 dill 是否生成正确时          |
| `bin/snapshot.dart`     | 转发到 `inner/snapshot.dart` 执行快照构建 | `inner/` 代码发生改变后，重新生成快照 |

## 1. debug_server.dart

### 用途

- 需要调试 `inner/` 代码时运行。
- 以源码方式调用 `inner/flutter_frontend_server/server.dart`，支持对 frontend_server 与 AOP 注入链路打断点。

### 运行模式

1. 自动发现模式（不传参数）
- 自动推导 Flutter SDK 根目录。
- 自动寻找 `example/.dart_tool/flutter_build/` 最新 hash 目录。
- 自动查找 depfile。
- 自动删除旧 `app.dill`，避免复用旧产物导致 AOP 信息缺失。

2. 手动透传模式（传入参数）
- 直接把传入参数转发给 `server.starter(args)`。
- 适合复现 flutter_tools 打印出的 frontend_server 启动参数。

### 运行方式

必须通过 VS Code 调试面板运行，不要直接点击编辑器右上角的 Run 按钮：

1. 打开「运行和调试」面板（`Ctrl+Shift+D`）。
2. 下拉框选择 **Debug debug_server.dart (inner packages)**。
3. 按 `F5` 启动，可在 `inner/flutter_frontend_server/` 任意位置设置断点。

## 2. dump.dart

### 用途

- 需要验证 dill 是否生成正确时运行。
- 调用 `inner/pkg/vm/bin/dump_kernel.dart`，把二进制 `app.dill` 转成文本，方便检索类、方法与 Hook 替换结果。

### 参数说明

- 第 1 个参数：输入 dill 路径（可选）。
- 第 2 个参数：输出文本路径（可选，默认仓库根目录 `out.dill.txt`）。

不传输入路径时，会自动选择 `example/.dart_tool/flutter_build/**/app.dill` 中最新文件。

### 运行方式

在编辑器中打开 `bin/dump.dart`，直接点击右上角 **Run** 按钮运行。
不传参数时，脚本会自动定位最新 `app.dill` 并输出到仓库根目录 `out.dill.txt`。

## 3. snapshot.dart

### 用途

- `inner/` 目录下的代码发生改变后运行，重新生成快照。
- 该脚本本身只做入口转发，调用 `inner/snapshot.dart` 执行实际构建流程。

### 运行方式

在编辑器中打开 `bin/snapshot.dart`，直接点击右上角 **Run** 按钮运行。

## 典型使用顺序

1. 修改了 `inner/` 代码后 → 运行 `snapshot.dart` 重新生成快照。
2. 运行完构建后 → 运行 `dump.dart` 验证 `app.dill` 中 Hook 是否正确写入。
3. 发现行为异常需要深入排查 → 运行 `debug_server.dart` 断点调试 `inner/` 代码。
