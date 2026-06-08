// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart' show Component, Library;
import 'package:kernel/class_hierarchy.dart' show ClassHierarchy;
import 'package:kernel/core_types.dart' show CoreTypes;
import 'package:kernel/reference_from_index.dart' show ReferenceFromIndex;
import 'package:kernel/target/changed_structure_notifier.dart';
import 'package:kernel/target/targets.dart';
import 'package:kernel/transformations/track_widget_constructor_locations.dart';
import 'package:vm/modular/target/vm.dart' show VmTarget;

abstract class FlutterProgramTransformer {
  void transform(Component component, {void Function(String msg)? logger});

  /// Phase 1 hook: invoked before constant evaluation. Use this to emit
  /// kernel nodes that need to be folded into Constants by the constant
  /// evaluator (for example, AOP-specific widget creation tracking).
  /// Default is a no-op.
  void transformWidgetCreator(Component component,
      {void Function(String msg)? logger}) {}
}

class FlutterTarget extends VmTarget {
  FlutterTarget(TargetFlags flags) : super(flags);

  late final WidgetCreatorTracker _widgetTracker = WidgetCreatorTracker();

  static List<FlutterProgramTransformer> _flutterProgramTransformers = [];
  static List<FlutterProgramTransformer> get flutterProgramTransformers => _flutterProgramTransformers;

  @override
  String get name => 'flutter';

  // This is the order that bootstrap libraries are loaded according to
  // `runtime/vm/object_store.h`.
  @override
  List<String> get extraRequiredLibraries => const <String>[
    'dart:async',
    'dart:collection',
    'dart:concurrent',
    'dart:convert',
    'dart:developer',
    'dart:ffi',
    'dart:_internal',
    'dart:isolate',
    'dart:math',

    // The library dart:mirrors may be ignored by the VM, e.g. when built in
    // PRODUCT mode.
    'dart:mirrors',

    'dart:typed_data',
    'dart:_vm',
    'dart:nativewrappers',
    'dart:io',

    // Required for flutter.
    'dart:ui',
    'dart:vmservice_io',
  ];

  @override
  List<String> get extraRequiredLibrariesPlatform => const <String>[];

  @override
  DartLibrarySupport get dartLibrarySupport =>
      const CustomizedDartLibrarySupport(unsupported: {'mirrors'});

  @override
  void performPreConstantEvaluationTransformations(
    Component component,
    CoreTypes coreTypes,
    List<Library> libraries,
    DiagnosticReporter diagnosticReporter, {
    void Function(String msg)? logger,
    ChangedStructureNotifier? changedStructureNotifier,
  }) {
    // Run AOP-specific widget creator tracking BEFORE constant evaluation so
    // that the ConstConstructorInvocation nodes it emits get folded into
    // Constants by the constant evaluator.
    if (_flutterProgramTransformers.isNotEmpty) {
      for (final FlutterProgramTransformer t in _flutterProgramTransformers) {
        t.transformWidgetCreator(component, logger: logger);
      }
    }
    super.performPreConstantEvaluationTransformations(
      component,
      coreTypes,
      libraries,
      diagnosticReporter,
      logger: logger,
      changedStructureNotifier: changedStructureNotifier,
    );
    // When AOP-specific widget tracking is active, skip the stock
    // WidgetCreatorTracker to avoid emitting two competing _location/aopLocation
    // implementations on the same constructors.
    if (flags.trackWidgetCreation && _flutterProgramTransformers.isEmpty) {
      _widgetTracker.transform(component, libraries, changedStructureNotifier);
    }
  }

  @override
  void performModularTransformationsOnLibraries(
    Component component,
    CoreTypes coreTypes,
    ClassHierarchy hierarchy,
    List<Library> libraries,
    Map<String, String>? environmentDefines,
    DiagnosticReporter diagnosticReporter,
    ReferenceFromIndex? referenceFromIndex, {
    void Function(String msg)? logger,
    ChangedStructureNotifier? changedStructureNotifier,
  }) {
    super.performModularTransformationsOnLibraries(
      component,
      coreTypes,
      hierarchy,
      libraries,
      environmentDefines,
      diagnosticReporter,
      referenceFromIndex,
      logger: logger,
      changedStructureNotifier: changedStructureNotifier,
    );
    // AOP transformers must run after constant evaluation so that
    // annotations on aspect classes / members are already
    // ConstantExpression instead of RedirectingFactoryInvocation.
    if (_flutterProgramTransformers.isNotEmpty) {
      final int len = _flutterProgramTransformers.length;
      for (int i = 0; i < len; i++) {
        _flutterProgramTransformers[i].transform(component, logger: logger);
      }
    }
  }
}
