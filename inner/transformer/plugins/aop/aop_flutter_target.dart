// Copyright 2024 Beike. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The method signatures here mirror upstream `pkg/vm` SDK code which uses the
// raw `DiagnosticReporter` generic. Suppress the workspace-level lint locally
// rather than diverge from the upstream signature.
// ignore_for_file: always_specify_types

import 'package:kernel/ast.dart' show Component, Library;
import 'package:kernel/class_hierarchy.dart' show ClassHierarchy;
import 'package:kernel/core_types.dart' show CoreTypes;
import 'package:kernel/reference_from_index.dart' show ReferenceFromIndex;
import 'package:kernel/target/changed_structure_notifier.dart';
import 'package:kernel/target/targets.dart'
    show DiagnosticReporter, TargetFlags, targets;
import 'package:vm/modular/target/flutter.dart' show FlutterTarget;
import 'package:vm/modular/target/install.dart' show installAdditionalTargets;

import 'aop_transformer_wrapper.dart';

/// A [FlutterTarget] subclass that wires AspectD AOP transformations into the
/// kernel pipeline without modifying the SDK's pristine `pkg/vm` sources.
///
/// AOP needs two distinct hook points:
///   1. **Pre constant-evaluation** — emit the AOP `aopLocation` widget creator
///      info so the resulting `ConstConstructorInvocation` nodes get folded
///      into `Constant`s by the constant evaluator.
///   2. **Post modular transformations** — run the actual AOP rewriters after
///      annotations have been promoted to `ConstantExpression`s.
///
/// The AOP widget tracker uses a different parameter name
/// (`$creationLocationAopd_…`) and a different field name (`aopLocation`)
/// from the upstream stock tracker (`$creationLocationd_…` / `_location`).
/// Because the two trackers no longer share any kernel-level identifier, they
/// can run on the same constructor without colliding: the stock tracker still
/// powers the DevTools widget inspector, and AOP drives its own runtime.
class AspectdFlutterTarget extends FlutterTarget {
  AspectdFlutterTarget(TargetFlags flags) : super(flags);

  final AopWrapperTransformer _aopTransformer = AopWrapperTransformer();

  @override
  void performPreConstantEvaluationTransformations(
    Component component,
    CoreTypes coreTypes,
    List<Library> libraries,
    DiagnosticReporter diagnosticReporter, {
    void Function(String msg)? logger,
    ChangedStructureNotifier? changedStructureNotifier,
  }) {
    // Phase 1: emit AOP widget creation tracking BEFORE constant evaluation
    // so the ConstConstructorInvocation nodes get folded into Constants.
    _aopTransformer.transformWidgetCreator(component, logger: logger);

    super.performPreConstantEvaluationTransformations(
      component,
      coreTypes,
      libraries,
      diagnosticReporter,
      logger: logger,
      changedStructureNotifier: changedStructureNotifier,
    );
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

    // Phase 2: AOP rewrites must run AFTER constant evaluation so that
    // annotations are stored as ConstantExpression rather than
    // RedirectingFactoryInvocation.
    _aopTransformer.transform(component, logger: logger);
  }
}

/// Replaces `targets['flutter']` with a builder that produces an
/// [AspectdFlutterTarget]. Idempotent — safe to call multiple times.
///
/// Must be called BEFORE [FrontendCompiler.compile] resolves the target
/// (i.e. before any code path that runs `createFrontEndTarget('flutter', …)`).
void installAspectdFlutterTarget() {
  // Make sure the upstream targets are installed first; `installAdditionalTargets`
  // is idempotent and registers the vanilla `flutter` builder. We then override
  // it with our AOP-aware builder.
  installAdditionalTargets();
  targets['flutter'] = (TargetFlags flags) => AspectdFlutterTarget(flags);
}
