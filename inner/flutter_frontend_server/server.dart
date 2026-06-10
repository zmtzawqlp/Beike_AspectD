// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:args/args.dart';
import 'package:frontend_server/frontend_server.dart' as frontend
    show
        FrontendCompiler,
        CompilerInterface,
        argParser,
        usage,
        ProgramTransformer;
import 'package:frontend_server/starter.dart' as frontend_starter
    show starter;
import 'package:kernel/ast.dart';
import 'package:vm/incremental_compiler.dart';

import '../transformer/plugins/aop/aop_flutter_target.dart';

/// Wrapper around [FrontendCompiler] that, when AOP is enabled, installs the
/// [AspectdFlutterTarget] in the global `targets['flutter']` map BEFORE
/// delegating to the underlying compiler. The target itself owns the AOP
/// transformer instance, so AOP survives `recompile-delta` cycles without
/// any extra bookkeeping here.
class _FlutterFrontendCompiler implements frontend.CompilerInterface {
  _FlutterFrontendCompiler(
    StringSink? output, {
    bool? unsafePackageSerialization,
    frontend.ProgramTransformer? transformer,
    this.aopTransform = false,
  }) : _compiler = frontend.FrontendCompiler(
          output,
          transformer: transformer,
          unsafePackageSerialization: unsafePackageSerialization,
        );

  final frontend.CompilerInterface _compiler;
  final bool aopTransform;
  bool _targetInstalled = false;

  void _ensureAopTargetInstalled() {
    if (aopTransform && !_targetInstalled) {
      installAspectdFlutterTarget();
      _targetInstalled = true;
    }
  }

  @override
  Future<bool> compile(String filename, ArgResults options,
      {IncrementalCompiler? generator}) async {
    print('aop: need perform $aopTransform');
    _ensureAopTargetInstalled();
    return _compiler.compile(filename, options, generator: generator);
  }

  @override
  Future<void> recompileDelta(
      {String? entryPoint, bool recompileRestart = false}) async {
    // Target instance lives inside IncrementalCompiler and already holds the
    // AOP transformer; no static-list housekeeping needed.
    return _compiler.recompileDelta(
        entryPoint: entryPoint, recompileRestart: recompileRestart);
  }

  @override
  void acceptLastDelta() {
    _compiler.acceptLastDelta();
  }

  @override
  Future<void> rejectLastDelta() async {
    return _compiler.rejectLastDelta();
  }

  @override
  void invalidate(Uri uri) {
    _compiler.invalidate(uri);
  }

  @override
  Future<void> compileExpression(
      String expression,
      List<String> definitions,
      List<String> definitionTypes,
      List<String> typeDefinitions,
      List<String> typeBounds,
      List<String> typeDefaults,
      String libraryUri,
      String? klass,
      String? method,
      int offset,
      String? scriptUri,
      bool isStatic) {
    return _compiler.compileExpression(
        expression,
        definitions,
        definitionTypes,
        typeDefinitions,
        typeBounds,
        typeDefaults,
        libraryUri,
        klass,
        method,
        offset,
        scriptUri,
        isStatic);
  }

  @override
  Future<void> compileExpressionToJs(
    String libraryUri,
    String? scriptUri,
    int line,
    int column,
    Map<String, String> jsModules,
    Map<String, String> jsFrameValues,
    String expression,
  ) {
    return _compiler.compileExpressionToJs(
      libraryUri,
      scriptUri,
      line,
      column,
      jsModules,
      jsFrameValues,
      expression,
    );
  }

  @override
  void reportError(String msg) {
    _compiler.reportError(msg);
  }

  @override
  void resetIncrementalCompiler() {
    _compiler.resetIncrementalCompiler();
  }

  @override
  Future<bool> setNativeAssets(String nativeAssets) {
    return _compiler.setNativeAssets(nativeAssets);
  }

  @override
  Future<bool> compileNativeAssetsOnly(ArgResults options,
      {IncrementalCompiler? generator}) {
    return _compiler.compileNativeAssetsOnly(options, generator: generator);
  }
}

bool _aopOptionRegistered = false;

/// Idempotent: registers the `--aop` option exactly once on the shared
/// `frontend.argParser`, so subsequent parses inside pkg `starter` accept it.
void _registerAopOption() {
  if (_aopOptionRegistered) {
    return;
  }
  frontend.argParser.addOption('aop', help: 'aop transform');
  _aopOptionRegistered = true;
}

/// Entry point for the Flutter-side frontend server.
///
/// Strategy: do the minimum amount of pre-processing required to wire AOP
/// (parse `--aop`, build a [_FlutterFrontendCompiler], install the
/// `AspectdFlutterTarget` lazily on first compile) and then hand the rest of
/// the lifecycle off to the upstream pkg `starter`. This way we automatically
/// inherit resident-compiler mode, native-assets-only mode, train mode, and
/// any future modes added upstream — without duplicating the dispatch logic
/// here.
Future<int> starter(
  List<String> args, {
  frontend.CompilerInterface? compiler,
  Stream<List<int>>? input,
  StringSink? output,
  frontend.ProgramTransformer? transformer,
}) async {
  _registerAopOption();

  ArgResults options;
  try {
    options = frontend.argParser.parse(args);
  } catch (error) {
    print('ERROR: $error\n');
    print(frontend.usage);
    return 1;
  }

  final Set<String> deleteToStringPackageUris =
      (options['delete-tostring-package-uri'] as List<String>).toSet();
  final bool aopEnabled = options['aop']?.toString() == '1';

  if (aopEnabled) {
    compiler ??= _FlutterFrontendCompiler(
      output,
      transformer: ToStringTransformer(transformer, deleteToStringPackageUris),
      unsafePackageSerialization:
          options['unsafe-package-serialization'] as bool,
      aopTransform: true,
    );
  }

  // Delegate the full lifecycle (including --train, resident mode,
  // --native-assets-only, single-shot compile and stdin server) to the
  // upstream starter. Our compiler instance plugs the AOP target in lazily
  // on its first `compile` call.
  return frontend_starter.starter(
    args,
    compiler: compiler,
    input: input,
    output: output,
  );
}

// Transformer/visitor for toString
// If we add any more of these, they really should go into a separate library.

/// A [RecursiveVisitor] that replaces [Object.toString] overrides with
/// `super.toString()`.
class ToStringVisitor extends RecursiveVisitor {
  ToStringVisitor(this._packageUris);

  /// A set of package URIs to apply this transformer to, e.g. 'dart:ui' and
  /// 'package:flutter/foundation.dart'.
  final Set<String> _packageUris;

  /// Turn 'dart:ui' into 'dart:ui', or
  /// 'package:flutter/src/semantics_event.dart' into 'package:flutter'.
  String _importUriToPackage(Uri importUri) =>
      '${importUri.scheme}:${importUri.pathSegments.first}';

  bool _isInTargetPackage(Procedure node) {
    return _packageUris
        .contains(_importUriToPackage(node.enclosingLibrary.importUri));
  }

  bool _hasKeepAnnotation(Procedure node) {
    for (ConstantExpression expression
        in node.annotations.whereType<ConstantExpression>()) {
      if (expression.constant is! InstanceConstant) {
        continue;
      }
      final InstanceConstant constant = expression.constant as InstanceConstant;
      if (constant.classNode.name == '_KeepToString' &&
          constant.classNode.enclosingLibrary.importUri.toString() ==
              'dart:ui') {
        return true;
      }
    }
    return false;
  }

  Procedure _getSuperMethodTarget(Procedure node) {
    Class? currentClass = node.enclosingClass?.superclass;
    while (currentClass != null) {
      for (final Procedure procedure in currentClass.procedures) {
        if (procedure.name == node.name) {
          return procedure;
        }
      }
      currentClass = currentClass.superclass;
    }
    return node;
  }

  @override
  void visitProcedure(Procedure node) {
    if (node.name.text == 'toString' &&
        node.enclosingClass != null &&
        !node.isStatic &&
        !node.isAbstract &&
        !node.enclosingClass!.isEnum &&
        _isInTargetPackage(node) &&
        !_hasKeepAnnotation(node)) {
      node.function.body?.replaceWith(
        ReturnStatement(
          SuperMethodInvocation(
            node.name,
            Arguments(<Expression>[]),node
          ),
        ),
      );
    }
  }

  @override
  void defaultMember(Member node) {}
}

/// Replaces [Object.toString] overrides with calls to super for the specified
/// [packageUris].
class ToStringTransformer extends frontend.ProgramTransformer {
  ToStringTransformer(this._child, this._packageUris);

  final frontend.ProgramTransformer? _child;

  /// A set of package URIs to apply this transformer to, e.g. 'dart:ui' and
  /// 'package:flutter/foundation.dart'.
  final Set<String> _packageUris;

  @override
  void transform(Component component) {
    assert(_child is! ToStringTransformer);
    if (_packageUris.isNotEmpty) {
      component.visitChildren(ToStringVisitor(_packageUris));
    }
    _child?.transform(component);
  }
}
