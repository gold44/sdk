// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/dart/error/hint_codes.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'non_hint_code_driver_test.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NonHintCodeTest_Kernel);
  });
}

/// Tests marked with this annotation fail because they test features that
/// were implemented in Analyzer, but are intentionally not included into
/// the Dart 2.0 plan, or disabled for Dart 2.0 altogether.
const notForDart2 = const Object();

/// Tests marked with this annotations fail because we either have not triaged
/// them, or know that this is an analyzer problem.
const potentialAnalyzerProblem = const Object();

/// Tests marked with this annotation fail because of a Fasta problem.
class FastaProblem {
  const FastaProblem(String issueUri);
}

@reflectiveTest
class NonHintCodeTest_Kernel extends NonHintCodeTest_Driver {
  @override
  bool get enableKernelDriver => true;

  @override
  bool get useCFE => true;

  @failingTest
  @override
  @potentialAnalyzerProblem
  test_deprecatedMemberUse_inDeprecatedLibrary() async {
    // LibraryAnalyzer is not applying resolution data to annotations on
    // directives.
    await super.test_deprecatedMemberUse_inDeprecatedLibrary();
  }

  @override
  @failingTest
  test_overrideOnNonOverridingField_inInterface() {
    // Expected 1 errors of type
    // StrongModeCode.STRONG_MODE_INVALID_METHOD_OVERRIDE, found 0
    return super.test_overrideOnNonOverridingField_inInterface();
  }

  @override
  @failingTest
  test_overrideOnNonOverridingField_inSuperclass() {
    // Expected 1 errors of type
    // StrongModeCode.STRONG_MODE_INVALID_METHOD_OVERRIDE, found 0
    return super.test_overrideOnNonOverridingField_inSuperclass();
  }

  @override
  @failingTest
  @notForDart2
  test_undefinedOperator_binaryExpression_inSubtype() async {
    await super.test_undefinedOperator_binaryExpression_inSubtype();
  }

  @override
  @failingTest
  @notForDart2
  test_undefinedOperator_indexBoth_inSubtype() async {
    await super.test_undefinedOperator_indexBoth_inSubtype();
  }

  @override
  @failingTest
  @notForDart2
  test_undefinedOperator_indexGetter_inSubtype() async {
    await super.test_undefinedOperator_indexGetter_inSubtype();
  }

  @override
  @failingTest
  @notForDart2
  test_undefinedOperator_indexSetter_inSubtype() async {
    await super.test_undefinedOperator_indexSetter_inSubtype();
  }

  @override
  test_unnecessaryCast_generics() async {
    // dartbug.com/18953
    // Overridden because type inference now produces more information and there
    // should now be a hint, where there wasn't one before.
    Source source = addSource(r'''
import 'dart:async';
Future<int> f() => new Future.value(0);
void g(bool c) {
  (c ? f(): new Future.value(0) as Future<int>).then((int value) {});
}''');
    await computeAnalysisResult(source);
    assertErrors(source, [HintCode.UNNECESSARY_CAST]);
    verify([source]);
  }

  @override
  @failingTest
  @potentialAnalyzerProblem
  test_unusedImport_annotationOnDirective() async {
    // Expected 0 errors of type HintCode.UNUSED_IMPORT, found 1 (23)
    await super.test_unusedImport_annotationOnDirective();
  }

  @failingTest
  @override
  @potentialAnalyzerProblem
  test_unusedImport_metadata() async {
    await super.test_unusedImport_metadata();
  }

  @override
  @failingTest
  @FastaProblem('https://github.com/dart-lang/sdk/issues/33678')
  test_withSuperMixin() async {
    // Expected 0 errors of type StaticTypeWarningCode.UNDEFINED_SUPER_GETTER, found 1 (82)
    await super.test_withSuperMixin();
  }
}
