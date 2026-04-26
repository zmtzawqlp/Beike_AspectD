## 目标
这份文档说明如何在 VS Code 中对 AOP frontend_server 源码打断点调试，以及如何获取和使用 frontend_server 启动参数。

## 前置条件
1. 已在 flutter_tools 中加了参数打印（compile.dart 里的 Debug frontend_server start args 日志）。
2. 在 example 目录做过至少一次 Debug 构建，确保 .dart_tool/flutter_build 目录存在。
3. VS Code 已安装 Dart 插件。

## 一、VS Code 一键 Debug（推荐方式）

仓库根目录已经配置好了 .vscode/launch.json，包含名为
"Debug debug_server.dart (inner packages)"
的调试配置。

启动步骤：
1. 在 VS Code 左侧点击 Run and Debug（或按 Ctrl+Shift+D）。
2. 顶部下拉选择 "Debug debug_server.dart (inner packages)"。
3. 按 F5 启动，在 server.dart / aop_transformer_wrapper.dart 等源码文件里直接打断点即可。

关键配置说明（.vscode/launch.json）：
```json
{
  "name": "Debug debug_server.dart (inner packages)",
  "type": "dart",
  "request": "launch",
  "program": "${workspaceFolder}/bin/debug_server.dart",
  "cwd": "${workspaceFolder}/example",
  "vmAdditionalArgs": [
    "--packages=${workspaceFolder}/inner/.dart_tool/package_config.json"
  ]
}
```

为什么需要 vmAdditionalArgs：
- debug_server.dart 依赖 inner/flutter_frontend_server/server.dart。
- server.dart 又依赖 package:frontend_server、package:kernel、package:vm 等 Dart SDK 内部包。
- 这些包只在 inner/.dart_tool/package_config.json 中有映射，不在根目录的 pubspec 里。
- 不加这个参数直接运行会报：Not found: 'package:frontend_server/...'。

## 二、复制 frontend_server 参数（可选，用于手动验证）

如果你想严格复现某次真实构建的参数，可以从 flutter_tools 日志里复制。

在控制台搜索关键字：
Debug frontend_server start args:

你会看到类似一整行：
Debug frontend_server start args: D:/.../frontend_server_aot.dart.snapshot --sdk-root ... --target=flutter ... package:example/main.dart

使用规则：
1. 去掉行首的 frontend_server_aot.dart.snapshot 路径（那是 AOT 快照入口，源码调试不需要）。
2. 保留从 --sdk-root 开始到末尾 package:example/main.dart 的全部参数。
3. 把这段参数粘贴到 VS Code 调试配置的 args 字段，或者在 launch.json 里加一个手动透传配置（见下方）。

手动透传配置示例（追加到 launch.json 的 configurations 数组）：
```json
{
  "name": "Debug debug_server.dart (manual args)",
  "type": "dart",
  "request": "launch",
  "program": "${workspaceFolder}/bin/debug_server.dart",
  "cwd": "${workspaceFolder}/example",
  "vmAdditionalArgs": [
    "--packages=${workspaceFolder}/inner/.dart_tool/package_config.json"
  ],
  "args": [
    "--sdk-root", "/path/to/flutter_patched_sdk/",
    "--target=flutter",
    "...",
    "package:example/main.dart"
  ]
}
```

## 三、debug_server.dart 自动构造模式说明

Program arguments 留空时，脚本会自动：
1. 从 example/.dart_tool/package_config.json 推导 Flutter SDK 根目录。
2. 查找 example/.dart_tool/flutter_build 下最新 hash 目录。
3. 删除已有的 app.dill（重要：旧 dill 里的 @Aspect() 注解已被 AOP transformer 删除，
   必须强制全量编译才能让 aopItemInfoList 有数据）。
4. 通过 flutter --version --machine 动态读取版本 -D 参数。
5. 拼出完整 builtArgs 并打印到控制台，方便对照检查。

## 四、常见问题

1. 报 Not found: 'package:frontend_server/...'：
   原因：没有用 inner 的 package_config 运行。
   解法：必须通过 .vscode/launch.json 配置启动，不要直接 Run 文件。

2. aopItemInfoList 为空，AOP 不生效：
   原因：app.dill 是上次 flutter run 处理过的产物，@Aspect() 注解已被删除。
   解法：debug_server.dart 启动时会自动删除 app.dill，重新全量编译。
   如果手动透传参数，不要带 --initialize-from-dill。

3. 没有 flutter_build hash 目录：
   先在 example 下执行一次：flutter run 或 flutter build apk --debug。

4. 版本 -D 参数为空：
   检查 Flutter SDK 路径是否正确，执行 flutter --version --machine 验证。
