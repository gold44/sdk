// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart2js.world;

import 'package:front_end/src/fasta/util/link.dart' show Link;

import 'common.dart';
import 'common/names.dart';
import 'common_elements.dart' show CommonElements, ElementEnvironment;
import 'constants/constant_system.dart';
import 'elements/entities.dart';
import 'elements/types.dart';
import 'js_backend/allocator_analysis.dart'
    show JAllocatorAnalysis, KAllocatorAnalysis;
import 'js_backend/backend_usage.dart' show BackendUsage;
import 'js_backend/interceptor_data.dart' show InterceptorData;
import 'js_backend/native_data.dart' show NativeData;
import 'js_backend/no_such_method_registry.dart' show NoSuchMethodData;
import 'js_backend/runtime_types.dart'
    show RuntimeTypesNeed, RuntimeTypesNeedBuilder;
import 'ordered_typeset.dart';
import 'options.dart';
import 'types/abstract_value_domain.dart';
import 'universe/class_hierarchy.dart';
import 'universe/class_set.dart';
import 'universe/function_set.dart' show FunctionSet;
import 'universe/selector.dart' show Selector;
import 'universe/world_builder.dart';

/// Common superinterface for [OpenWorld] and [JClosedWorld].
abstract class World {}

/// The [JClosedWorld] represents the information known about a program when
/// compiling with closed-world semantics.
///
/// Given the entrypoint of an application, we can track what's reachable from
/// it, what functions are called, what classes are allocated, which native
/// JavaScript types are touched, what language features are used, and so on.
/// This precise knowledge about what's live in the program is later used in
/// optimizations and other compiler decisions during code generation.
// TODO(johnniwinther): Maybe this should just be called the JWorld.
abstract class JClosedWorld implements World {
  JAllocatorAnalysis get allocatorAnalysis;

  BackendUsage get backendUsage;

  NativeData get nativeData;

  InterceptorData get interceptorData;

  ElementEnvironment get elementEnvironment;

  DartTypes get dartTypes;

  CommonElements get commonElements;

  /// Returns the [AbstractValueDomain] used in the global type inference.
  AbstractValueDomain get abstractValueDomain;

  ConstantSystem get constantSystem;

  RuntimeTypesNeed get rtiNeed;

  NoSuchMethodData get noSuchMethodData;

  Iterable<ClassEntity> get liveNativeClasses;

  Iterable<MemberEntity> get processedMembers;

  ClassHierarchy get classHierarchy;

  /// Returns `true` if [cls] is either directly or indirectly instantiated.
  bool isInstantiated(ClassEntity cls);

  /// Returns `true` if [cls] is directly instantiated. This means that at
  /// runtime instances of exactly [cls] are assumed to exist.
  bool isDirectlyInstantiated(ClassEntity cls);

  /// Returns `true` if [cls] is abstractly instantiated. This means that at
  /// runtime instances of [cls] or unknown subclasses of [cls] are assumed to
  /// exist.
  ///
  /// This is used to mark native and/or reflectable classes as instantiated.
  /// For native classes we do not know the exact class that instantiates [cls]
  /// so [cls] here represents the root of the subclasses. For reflectable
  /// classes we need event abstract classes to be 'live' even though they
  /// cannot themselves be instantiated.
  bool isAbstractlyInstantiated(ClassEntity cls);

  /// Returns `true` if [cls] is either directly or abstractly instantiated.
  ///
  /// See [isDirectlyInstantiated] and [isAbstractlyInstantiated].
  bool isExplicitlyInstantiated(ClassEntity cls);

  /// Returns `true` if [cls] is indirectly instantiated, that is through a
  /// subclass.
  bool isIndirectlyInstantiated(ClassEntity cls);

  /// Returns `true` if [cls] is implemented by an instantiated class.
  bool isImplemented(ClassEntity cls);

  /// Return `true` if [x] is a subclass of [y].
  bool isSubclassOf(ClassEntity x, ClassEntity y);

  /// Returns `true` if [x] is a subtype of [y], that is, if [x] implements an
  /// instance of [y].
  bool isSubtypeOf(ClassEntity x, ClassEntity y);

  /// Returns an iterable over the live classes that extend [cls] including
  /// [cls] itself.
  Iterable<ClassEntity> subclassesOf(ClassEntity cls);

  /// Returns an iterable over the live classes that extend [cls] _not_
  /// including [cls] itself.
  Iterable<ClassEntity> strictSubclassesOf(ClassEntity cls);

  /// Returns the number of live classes that extend [cls] _not_
  /// including [cls] itself.
  int strictSubclassCount(ClassEntity cls);

  /// Applies [f] to each live class that extend [cls] _not_ including [cls]
  /// itself.
  void forEachStrictSubclassOf(
      ClassEntity cls, IterationStep f(ClassEntity cls));

  /// Returns `true` if [predicate] applies to any live class that extend [cls]
  /// _not_ including [cls] itself.
  bool anyStrictSubclassOf(ClassEntity cls, bool predicate(ClassEntity cls));

  /// Returns an iterable over the directly instantiated that implement [cls]
  /// possibly including [cls] itself, if it is live.
  Iterable<ClassEntity> subtypesOf(ClassEntity cls);

  /// Returns an iterable over the live classes that implement [cls] _not_
  /// including [cls] if it is live.
  Iterable<ClassEntity> strictSubtypesOf(ClassEntity cls);

  /// Returns the number of live classes that implement [cls] _not_
  /// including [cls] itself.
  int strictSubtypeCount(ClassEntity cls);

  /// Applies [f] to each live class that implements [cls] _not_ including [cls]
  /// itself.
  void forEachStrictSubtypeOf(
      ClassEntity cls, IterationStep f(ClassEntity cls));

  /// Returns `true` if [predicate] applies to any live class that implements
  /// [cls] _not_ including [cls] itself.
  bool anyStrictSubtypeOf(ClassEntity cls, bool predicate(ClassEntity cls));

  /// Returns `true` if [a] and [b] have any known common subtypes.
  bool haveAnyCommonSubtypes(ClassEntity a, ClassEntity b);

  /// Returns `true` if any live class other than [cls] extends [cls].
  bool hasAnyStrictSubclass(ClassEntity cls);

  /// Returns `true` if any live class other than [cls] implements [cls].
  bool hasAnyStrictSubtype(ClassEntity cls);

  /// Returns `true` if all live classes that implement [cls] extend it.
  bool hasOnlySubclasses(ClassEntity cls);

  /// Returns the most specific subclass of [cls] (including [cls]) that is
  /// directly instantiated or a superclass of all directly instantiated
  /// subclasses. If [cls] is not instantiated, `null` is returned.
  ClassEntity getLubOfInstantiatedSubclasses(ClassEntity cls);

  /// Returns the most specific subtype of [cls] (including [cls]) that is
  /// directly instantiated or a superclass of all directly instantiated
  /// subtypes. If no subtypes of [cls] are instantiated, `null` is returned.
  ClassEntity getLubOfInstantiatedSubtypes(ClassEntity cls);

  /// Returns an iterable over the common supertypes of the [classes].
  Iterable<ClassEntity> commonSupertypesOf(Iterable<ClassEntity> classes);

  /// Returns an iterable over the live mixin applications that mixin [cls].
  Iterable<ClassEntity> mixinUsesOf(ClassEntity cls);

  /// Returns `true` if [cls] is mixed into a live class.
  bool isUsedAsMixin(ClassEntity cls);

  /// Returns `true` if any live class that mixes in [cls] implements [type].
  bool hasAnySubclassOfMixinUseThatImplements(
      ClassEntity cls, ClassEntity type);

  /// Returns `true` if any live class that mixes in [mixin] is also a subclass
  /// of [superclass].
  bool hasAnySubclassThatMixes(ClassEntity superclass, ClassEntity mixin);

  /// Returns `true` if [cls] or any superclass mixes in [mixin].
  bool isSubclassOfMixinUseOf(ClassEntity cls, ClassEntity mixin);

  /// Returns `true` if every subtype of [x] is a subclass of [y] or a subclass
  /// of a mixin application of [y].
  bool everySubtypeIsSubclassOfOrMixinUseOf(ClassEntity x, ClassEntity y);

  /// Returns `true` if any subclass of [superclass] implements [type].
  bool hasAnySubclassThatImplements(ClassEntity superclass, ClassEntity type);

  /// Returns `true` if a call of [selector] on [cls] and/or subclasses/subtypes
  /// need noSuchMethod handling.
  ///
  /// If the receiver is guaranteed to have a member that matches what we're
  /// looking for, there's no need to introduce a noSuchMethod handler. It will
  /// never be called.
  ///
  /// As an example, consider this class hierarchy:
  ///
  ///                   A    <-- noSuchMethod
  ///                  / \
  ///                 C   B  <-- foo
  ///
  /// If we know we're calling foo on an object of type B we don't have to worry
  /// about the noSuchMethod method in A because objects of type B implement
  /// foo. On the other hand, if we end up calling foo on something of type C we
  /// have to add a handler for it.
  ///
  /// If the holders of all user-defined noSuchMethod implementations that might
  /// be applicable to the receiver type have a matching member for the current
  /// name and selector, we avoid introducing a noSuchMethod handler.
  ///
  /// As an example, consider this class hierarchy:
  ///
  ///                        A    <-- foo
  ///                       / \
  ///    noSuchMethod -->  B   C  <-- bar
  ///                      |   |
  ///                      C   D  <-- noSuchMethod
  ///
  /// When calling foo on an object of type A, we know that the implementations
  /// of noSuchMethod are in the classes B and D that also (indirectly)
  /// implement foo, so we do not need a handler for it.
  ///
  /// If we're calling bar on an object of type D, we don't need the handler
  /// either because all objects of type D implement bar through inheritance.
  ///
  /// If we're calling bar on an object of type A we do need the handler because
  /// we may have to call B.noSuchMethod since B does not implement bar.
  bool needsNoSuchMethod(ClassEntity cls, Selector selector, ClassQuery query);

  /// Returns whether [element] will be the one used at runtime when being
  /// invoked on an instance of [cls]. [selector] is used to ensure library
  /// privacy is taken into account.
  bool hasElementIn(
      covariant ClassEntity cls, Selector selector, covariant Entity element);

  /// Returns [ClassHierarchyNode] for [cls] used to model the class hierarchies
  /// of known classes.
  ///
  /// This method is only provided for testing. For queries on classes, use the
  /// methods defined in [JClosedWorld].
  ClassHierarchyNode getClassHierarchyNode(ClassEntity cls);

  /// Returns [ClassSet] for [cls] used to model the extends and implements
  /// relations of known classes.
  ///
  /// This method is only provided for testing. For queries on classes, use the
  /// methods defined in [JClosedWorld].
  ClassSet getClassSet(ClassEntity cls);

  /// Returns `true` if the field [element] is known to be effectively final.
  bool fieldNeverChanges(MemberEntity element);

  /// Extends the [receiver] type for calling [selector] to take live
  /// `noSuchMethod` handlers into account.
  AbstractValue extendMaskIfReachesAll(
      Selector selector, AbstractValue receiver);

  /// Returns `true` if [selector] on [receiver] can hit a `call` method on a
  /// subclass of `Closure`.
  ///
  /// Every implementation of `Closure` has a 'call' method with its own
  /// signature so it cannot be modelled by a [FunctionEntity]. Also,
  /// call-methods for tear-off are not part of the element model.
  bool includesClosureCall(Selector selector, AbstractValue receiver);

  /// Returns the mask for the potential receivers of a dynamic call to
  /// [selector] on [receiver].
  ///
  /// This will narrow the constraints of [receiver] to an [AbstractValue] of
  /// the set of classes that actually implement the selected member or
  /// implement the handling 'noSuchMethod' where the selected member is
  /// unimplemented.
  AbstractValue computeReceiverType(Selector selector, AbstractValue receiver);

  /// Returns all the instance members that may be invoked with the [selector]
  /// on the given [receiver]. The returned elements may include noSuchMethod
  /// handlers that are potential targets indirectly through the noSuchMethod
  /// mechanism.
  Iterable<MemberEntity> locateMembers(
      Selector selector, AbstractValue receiver);

  /// Returns the single [MemberEntity] that matches a call to [selector] on the
  /// [receiver]. If multiple targets exist, `null` is returned.
  MemberEntity locateSingleMember(Selector selector, AbstractValue receiver);

  /// Returns the single field that matches a call to [selector] on the
  /// [receiver]. If multiple targets exist or the single target is not a field,
  /// `null` is returned.
  FieldEntity locateSingleField(Selector selector, AbstractValue receiver);

  /// Returns a string representation of the closed world.
  ///
  /// If [cls] is provided, the dump will contain only classes related to [cls].
  String dump([ClassEntity cls]);

  /// Adds the closure class [cls] to the inference world. The class is
  /// considered directly instantiated. If [fromInstanceMember] is true, this
  /// closure class represents a closure that is inside an instance member, thus
  /// has access to `this`.
  void registerClosureClass(ClassEntity cls);
}

abstract class OpenWorld implements World {
  void registerUsedElement(MemberEntity element);

  KClosedWorld closeWorld();

  /// Returns an iterable over all mixin applications that mixin [cls].
  Iterable<ClassEntity> allMixinUsesOf(ClassEntity cls);

  /// Returns `true` if [member] is inherited into a subtype of [type].
  ///
  /// For instance:
  ///
  ///     class A { m() {} }
  ///     class B extends A implements I {}
  ///     class C extends Object with A implements I {}
  ///     abstract class I { m(); }
  ///     abstract class J implements A { }
  ///
  /// Here `A.m` is inherited into `A`, `B`, and `C`. Becausec `B` and
  /// `C` implement `I`, `isInheritedInSubtypeOf(A.M, I)` is true, but
  /// `isInheritedInSubtypeOf(A.M, J)` is false.
  bool isInheritedInSubtypeOf(MemberEntity member, ClassEntity type);
}

abstract class ClosedWorldBase implements JClosedWorld {
  final ConstantSystem constantSystem;
  final NativeData nativeData;
  final InterceptorData interceptorData;
  final BackendUsage backendUsage;
  final NoSuchMethodData noSuchMethodData;

  FunctionSet _allFunctions;

  final Map<ClassEntity, Set<ClassEntity>> mixinUses;
  Map<ClassEntity, List<ClassEntity>> _liveMixinUses;

  final Map<ClassEntity, Set<ClassEntity>> typesImplementedBySubclasses;

  final Map<ClassEntity, ClassHierarchyNode> _classHierarchyNodes;
  final Map<ClassEntity, ClassSet> _classSets;

  final Map<ClassEntity, Map<ClassEntity, bool>> _subtypeCoveredByCache =
      <ClassEntity, Map<ClassEntity, bool>>{};

  final ElementEnvironment elementEnvironment;
  final DartTypes dartTypes;
  final CommonElements commonElements;

  // TODO(johnniwinther): Can this be derived from [ClassSet]s?
  final Set<ClassEntity> _implementedClasses;

  final Iterable<MemberEntity> liveInstanceMembers;

  /// Members that are written either directly or through a setter selector.
  final Iterable<MemberEntity> assignedInstanceMembers;

  final Iterable<ClassEntity> liveNativeClasses;

  final Iterable<MemberEntity> processedMembers;

  final ClassHierarchy classHierarchy;

  ClosedWorldBase(
      this.elementEnvironment,
      this.dartTypes,
      this.commonElements,
      this.constantSystem,
      this.nativeData,
      this.interceptorData,
      this.backendUsage,
      this.noSuchMethodData,
      Set<ClassEntity> implementedClasses,
      this.liveNativeClasses,
      this.liveInstanceMembers,
      this.assignedInstanceMembers,
      this.processedMembers,
      this.mixinUses,
      this.typesImplementedBySubclasses,
      Map<ClassEntity, ClassHierarchyNode> classHierarchyNodes,
      Map<ClassEntity, ClassSet> classSets,
      AbstractValueStrategy abstractValueStrategy)
      : this._implementedClasses = implementedClasses,
        this._classHierarchyNodes = classHierarchyNodes,
        this._classSets = classSets,
        classHierarchy = new ClassHierarchyImpl(
            commonElements, classHierarchyNodes, classSets) {}

  bool checkEntity(covariant Entity element);

  bool checkInvariants(covariant ClassEntity cls,
      {bool mustBeInstantiated: true});

  OrderedTypeSet getOrderedTypeSet(covariant ClassEntity cls);

  int getHierarchyDepth(covariant ClassEntity cls);

  ClassEntity getSuperClass(covariant ClassEntity cls);

  Iterable<ClassEntity> getInterfaces(covariant ClassEntity cls);

  ClassEntity getAppliedMixin(covariant ClassEntity cls);

  bool isNamedMixinApplication(covariant ClassEntity cls);

  @override
  bool isInstantiated(ClassEntity cls) {
    ClassHierarchyNode node = _classHierarchyNodes[cls];
    return node != null && node.isInstantiated;
  }

  @override
  bool isDirectlyInstantiated(ClassEntity cls) {
    ClassHierarchyNode node = _classHierarchyNodes[cls];
    return node != null && node.isDirectlyInstantiated;
  }

  @override
  bool isAbstractlyInstantiated(ClassEntity cls) {
    ClassHierarchyNode node = _classHierarchyNodes[cls];
    return node != null && node.isAbstractlyInstantiated;
  }

  @override
  bool isExplicitlyInstantiated(ClassEntity cls) {
    ClassHierarchyNode node = _classHierarchyNodes[cls];
    return node != null && node.isExplicitlyInstantiated;
  }

  @override
  bool isIndirectlyInstantiated(ClassEntity cls) {
    ClassHierarchyNode node = _classHierarchyNodes[cls];
    return node != null && node.isIndirectlyInstantiated;
  }

  /// Returns `true` if [cls] is implemented by an instantiated class.
  bool isImplemented(ClassEntity cls) {
    return _implementedClasses.contains(cls);
  }

  /// Returns `true` if [x] is a subtype of [y], that is, if [x] implements an
  /// instance of [y].
  bool isSubtypeOf(ClassEntity x, ClassEntity y) {
    assert(checkInvariants(x));
    assert(checkInvariants(y, mustBeInstantiated: false));
    ClassSet classSet = _classSets[y];
    assert(
        classSet != null,
        failedAt(
            y,
            "No ClassSet for $y (${y.runtimeType}): "
            "${dump(y)} : ${_classSets}"));
    ClassHierarchyNode classHierarchyNode = _classHierarchyNodes[x];
    assert(classHierarchyNode != null,
        failedAt(x, "No ClassHierarchyNode for $x: ${dump(x)}"));
    return classSet.hasSubtype(classHierarchyNode);
  }

  /// Return `true` if [x] is a (non-strict) subclass of [y].
  bool isSubclassOf(ClassEntity x, ClassEntity y) {
    assert(checkInvariants(x));
    assert(checkInvariants(y));
    return _classHierarchyNodes[y].hasSubclass(_classHierarchyNodes[x]);
  }

  /// Returns an iterable over the directly instantiated classes that extend
  /// [cls] possibly including [cls] itself, if it is live.
  Iterable<ClassEntity> subclassesOf(ClassEntity cls) {
    ClassHierarchyNode hierarchy = _classHierarchyNodes[cls];
    if (hierarchy == null) return const <ClassEntity>[];
    return hierarchy
        .subclassesByMask(ClassHierarchyNode.EXPLICITLY_INSTANTIATED);
  }

  /// Returns an iterable over the directly instantiated classes that extend
  /// [cls] _not_ including [cls] itself.
  Iterable<ClassEntity> strictSubclassesOf(ClassEntity cls) {
    ClassHierarchyNode subclasses = _classHierarchyNodes[cls];
    if (subclasses == null) return const <ClassEntity>[];
    return subclasses.subclassesByMask(
        ClassHierarchyNode.EXPLICITLY_INSTANTIATED,
        strict: true);
  }

  /// Returns the number of live classes that extend [cls] _not_
  /// including [cls] itself.
  int strictSubclassCount(ClassEntity cls) {
    ClassHierarchyNode subclasses = _classHierarchyNodes[cls];
    if (subclasses == null) return 0;
    return subclasses.instantiatedSubclassCount;
  }

  /// Applies [f] to each live class that extend [cls] _not_ including [cls]
  /// itself.
  void forEachStrictSubclassOf(
      ClassEntity cls, IterationStep f(ClassEntity cls)) {
    ClassHierarchyNode subclasses = _classHierarchyNodes[cls];
    if (subclasses == null) return;
    subclasses.forEachSubclass(f, ClassHierarchyNode.EXPLICITLY_INSTANTIATED,
        strict: true);
  }

  /// Returns `true` if [predicate] applies to any live class that extend [cls]
  /// _not_ including [cls] itself.
  bool anyStrictSubclassOf(ClassEntity cls, bool predicate(ClassEntity cls)) {
    ClassHierarchyNode subclasses = _classHierarchyNodes[cls];
    if (subclasses == null) return false;
    return subclasses.anySubclass(
        predicate, ClassHierarchyNode.EXPLICITLY_INSTANTIATED,
        strict: true);
  }

  /// Returns an iterable over the directly instantiated that implement [cls]
  /// possibly including [cls] itself, if it is live.
  Iterable<ClassEntity> subtypesOf(ClassEntity cls) {
    ClassSet classSet = _classSets[cls];
    if (classSet == null) {
      return const <ClassEntity>[];
    } else {
      return classSet
          .subtypesByMask(ClassHierarchyNode.EXPLICITLY_INSTANTIATED);
    }
  }

  /// Returns an iterable over the directly instantiated that implement [cls]
  /// _not_ including [cls].
  Iterable<ClassEntity> strictSubtypesOf(ClassEntity cls) {
    ClassSet classSet = _classSets[cls];
    if (classSet == null) {
      return const <ClassEntity>[];
    } else {
      return classSet.subtypesByMask(ClassHierarchyNode.EXPLICITLY_INSTANTIATED,
          strict: true);
    }
  }

  /// Returns the number of live classes that implement [cls] _not_
  /// including [cls] itself.
  int strictSubtypeCount(ClassEntity cls) {
    ClassSet classSet = _classSets[cls];
    if (classSet == null) return 0;
    return classSet.instantiatedSubtypeCount;
  }

  /// Applies [f] to each live class that implements [cls] _not_ including [cls]
  /// itself.
  void forEachStrictSubtypeOf(
      ClassEntity cls, IterationStep f(ClassEntity cls)) {
    ClassSet classSet = _classSets[cls];
    if (classSet == null) return;
    classSet.forEachSubtype(f, ClassHierarchyNode.EXPLICITLY_INSTANTIATED,
        strict: true);
  }

  /// Returns `true` if [predicate] applies to any live class that extend [cls]
  /// _not_ including [cls] itself.
  bool anyStrictSubtypeOf(ClassEntity cls, bool predicate(ClassEntity cls)) {
    ClassSet classSet = _classSets[cls];
    if (classSet == null) return false;
    return classSet.anySubtype(
        predicate, ClassHierarchyNode.EXPLICITLY_INSTANTIATED,
        strict: true);
  }

  /// Returns `true` if [a] and [b] have any known common subtypes.
  bool haveAnyCommonSubtypes(ClassEntity a, ClassEntity b) {
    ClassSet classSetA = _classSets[a];
    ClassSet classSetB = _classSets[b];
    if (classSetA == null || classSetB == null) return false;
    // TODO(johnniwinther): Implement an optimized query on [ClassSet].
    Set<ClassEntity> subtypesOfB = classSetB.subtypes().toSet();
    for (ClassEntity subtypeOfA in classSetA.subtypes()) {
      if (subtypesOfB.contains(subtypeOfA)) {
        return true;
      }
    }
    return false;
  }

  /// Returns `true` if any directly instantiated class other than [cls] extends
  /// [cls].
  bool hasAnyStrictSubclass(ClassEntity cls) {
    ClassHierarchyNode subclasses = _classHierarchyNodes[cls];
    if (subclasses == null) return false;
    return subclasses.isIndirectlyInstantiated;
  }

  /// Returns `true` if any directly instantiated class other than [cls]
  /// implements [cls].
  bool hasAnyStrictSubtype(ClassEntity cls) {
    return strictSubtypeCount(cls) > 0;
  }

  /// Returns `true` if all directly instantiated classes that implement [cls]
  /// extend it.
  bool hasOnlySubclasses(ClassEntity cls) {
    // TODO(johnniwinther): move this to ClassSet?
    if (cls == commonElements.objectClass) return true;
    ClassSet classSet = _classSets[cls];
    if (classSet == null) {
      // Vacuously true.
      return true;
    }
    return classSet.hasOnlyInstantiatedSubclasses;
  }

  @override
  ClassEntity getLubOfInstantiatedSubclasses(ClassEntity cls) {
    if (nativeData.isJsInteropClass(cls)) {
      return commonElements.jsJavaScriptObjectClass;
    }
    ClassHierarchyNode hierarchy = _classHierarchyNodes[cls];
    return hierarchy != null
        ? hierarchy.getLubOfInstantiatedSubclasses()
        : null;
  }

  @override
  ClassEntity getLubOfInstantiatedSubtypes(ClassEntity cls) {
    if (nativeData.isJsInteropClass(cls)) {
      return commonElements.jsJavaScriptObjectClass;
    }
    ClassSet classSet = _classSets[cls];
    return classSet != null ? classSet.getLubOfInstantiatedSubtypes() : null;
  }

  /// Returns `true` if [cls] is mixed into a live class.
  bool isUsedAsMixin(ClassEntity cls) {
    return !mixinUsesOf(cls).isEmpty;
  }

  /// Returns `true` if any live class that mixes in [cls] implements [type].
  bool hasAnySubclassOfMixinUseThatImplements(
      ClassEntity cls, ClassEntity type) {
    return mixinUsesOf(cls)
        .any((use) => hasAnySubclassThatImplements(use, type));
  }

  /// Returns `true` if every subtype of [x] is a subclass of [y] or a subclass
  /// of a mixin application of [y].
  bool everySubtypeIsSubclassOfOrMixinUseOf(ClassEntity x, ClassEntity y) {
    Map<ClassEntity, bool> secondMap =
        _subtypeCoveredByCache[x] ??= <ClassEntity, bool>{};
    return secondMap[y] ??= subtypesOf(x).every((ClassEntity cls) =>
        isSubclassOf(cls, y) || isSubclassOfMixinUseOf(cls, y));
  }

  /// Returns `true` if any subclass of [superclass] implements [type].
  bool hasAnySubclassThatImplements(ClassEntity superclass, ClassEntity type) {
    Set<ClassEntity> subclasses = typesImplementedBySubclasses[superclass];
    if (subclasses == null) return false;
    return subclasses.contains(type);
  }

  /// Returns whether a [selector] call on an instance of [cls]
  /// will hit a method at runtime, and not go through [noSuchMethod].
  bool hasConcreteMatch(covariant ClassEntity cls, Selector selector,
      {covariant ClassEntity stopAtSuperclass});

  @override
  bool needsNoSuchMethod(
      ClassEntity base, Selector selector, ClassQuery query) {
    /// Returns `true` if subclasses in the [rootNode] tree needs noSuchMethod
    /// handling.
    bool subclassesNeedNoSuchMethod(ClassHierarchyNode rootNode) {
      if (!rootNode.isInstantiated) {
        // No subclass needs noSuchMethod handling since they are all
        // uninstantiated.
        return false;
      }
      ClassEntity rootClass = rootNode.cls;
      if (hasConcreteMatch(rootClass, selector)) {
        // The root subclass has a concrete implementation so no subclass needs
        // noSuchMethod handling.
        return false;
      } else if (rootNode.isExplicitlyInstantiated) {
        // The root class need noSuchMethod handling.
        return true;
      }
      IterationStep result = rootNode.forEachSubclass((ClassEntity subclass) {
        if (hasConcreteMatch(subclass, selector, stopAtSuperclass: rootClass)) {
          // Found a match - skip all subclasses.
          return IterationStep.SKIP_SUBCLASSES;
        } else {
          // Stop fast - we found a need for noSuchMethod handling.
          return IterationStep.STOP;
        }
      }, ClassHierarchyNode.EXPLICITLY_INSTANTIATED, strict: true);
      // We stopped fast so we need noSuchMethod handling.
      return result == IterationStep.STOP;
    }

    ClassSet classSet = getClassSet(base);
    assert(classSet != null, failedAt(base, "No class set for $base."));
    ClassHierarchyNode node = classSet.node;
    if (query == ClassQuery.EXACT) {
      return node.isExplicitlyInstantiated && !hasConcreteMatch(base, selector);
    } else if (query == ClassQuery.SUBCLASS) {
      return subclassesNeedNoSuchMethod(node);
    } else {
      if (subclassesNeedNoSuchMethod(node)) return true;
      for (ClassHierarchyNode subtypeNode in classSet.subtypeNodes) {
        if (subclassesNeedNoSuchMethod(subtypeNode)) return true;
      }
      return false;
    }
  }

  /// Returns an iterable over the common supertypes of the [classes].
  Iterable<ClassEntity> commonSupertypesOf(Iterable<ClassEntity> classes) {
    Iterator<ClassEntity> iterator = classes.iterator;
    if (!iterator.moveNext()) return const <ClassEntity>[];

    ClassEntity cls = iterator.current;
    assert(checkInvariants(cls));
    OrderedTypeSet typeSet = getOrderedTypeSet(cls);
    if (!iterator.moveNext()) return typeSet.types.map((type) => type.element);

    int depth = typeSet.maxDepth;
    Link<OrderedTypeSet> otherTypeSets = const Link<OrderedTypeSet>();
    do {
      ClassEntity otherClass = iterator.current;
      assert(checkInvariants(otherClass));
      OrderedTypeSet otherTypeSet = getOrderedTypeSet(otherClass);
      otherTypeSets = otherTypeSets.prepend(otherTypeSet);
      if (otherTypeSet.maxDepth < depth) {
        depth = otherTypeSet.maxDepth;
      }
    } while (iterator.moveNext());

    List<ClassEntity> commonSupertypes = <ClassEntity>[];
    OUTER:
    for (Link<InterfaceType> link = typeSet[depth];
        link.head.element != commonElements.objectClass;
        link = link.tail) {
      ClassEntity cls = link.head.element;
      for (Link<OrderedTypeSet> link = otherTypeSets;
          !link.isEmpty;
          link = link.tail) {
        if (link.head.asInstanceOf(cls, getHierarchyDepth(cls)) == null) {
          continue OUTER;
        }
      }
      commonSupertypes.add(cls);
    }
    commonSupertypes.add(commonElements.objectClass);
    return commonSupertypes;
  }

  /// Returns an iterable over the live mixin applications that mixin [cls].
  Iterable<ClassEntity> mixinUsesOf(ClassEntity cls) {
    if (_liveMixinUses == null) {
      _liveMixinUses = new Map<ClassEntity, List<ClassEntity>>();
      for (ClassEntity mixin in mixinUses.keys) {
        List<ClassEntity> uses = <ClassEntity>[];

        void addLiveUse(ClassEntity mixinApplication) {
          if (isInstantiated(mixinApplication)) {
            uses.add(mixinApplication);
          } else if (isNamedMixinApplication(mixinApplication)) {
            Set<ClassEntity> next = mixinUses[mixinApplication];
            if (next != null) {
              next.forEach(addLiveUse);
            }
          }
        }

        mixinUses[mixin].forEach(addLiveUse);
        if (uses.isNotEmpty) {
          _liveMixinUses[mixin] = uses;
        }
      }
    }
    Iterable<ClassEntity> uses = _liveMixinUses[cls];
    return uses != null ? uses : const <ClassEntity>[];
  }

  /// Returns `true` if any live class that mixes in [mixin] is also a subclass
  /// of [superclass].
  bool hasAnySubclassThatMixes(ClassEntity superclass, ClassEntity mixin) {
    return mixinUsesOf(mixin).any((ClassEntity each) {
      return isSubclassOf(each, superclass);
    });
  }

  /// Returns `true` if [cls] or any superclass mixes in [mixin].
  bool isSubclassOfMixinUseOf(ClassEntity cls, ClassEntity mixin) {
    if (isUsedAsMixin(mixin)) {
      ClassEntity current = cls;
      while (current != null) {
        ClassEntity currentMixin = getAppliedMixin(current);
        if (currentMixin == mixin) return true;
        current = getSuperClass(current);
      }
    }
    return false;
  }

  /// Returns [ClassHierarchyNode] for [cls] used to model the class hierarchies
  /// of known classes.
  ///
  /// This method is only provided for testing. For queries on classes, use the
  /// methods defined in [JClosedWorld].
  ClassHierarchyNode getClassHierarchyNode(ClassEntity cls) {
    return _classHierarchyNodes[cls];
  }

  /// Returns [ClassSet] for [cls] used to model the extends and implements
  /// relations of known classes.
  ///
  /// This method is only provided for testing. For queries on classes, use the
  /// methods defined in [JClosedWorld].
  ClassSet getClassSet(ClassEntity cls) {
    return _classSets[cls];
  }

  void _ensureFunctionSet() {
    if (_allFunctions == null) {
      // [FunctionSet] is created lazily because it is not used when we switch
      // from a frontend to a backend model before inference.
      _allFunctions = new FunctionSet(liveInstanceMembers);
    }
  }

  /// Returns `true` if [selector] on [receiver] can hit a `call` method on a
  /// subclass of `Closure`.
  ///
  /// Every implementation of `Closure` has a 'call' method with its own
  /// signature so it cannot be modelled by a [FunctionEntity]. Also,
  /// call-methods for tear-off are not part of the element model.
  bool includesClosureCall(Selector selector, AbstractValue receiver) {
    return selector.name == Identifiers.call &&
        (receiver == null ||
            // TODO(johnniwinther): Should this have been `intersects` instead?
            abstractValueDomain.contains(
                receiver, abstractValueDomain.functionType));
  }

  AbstractValue computeReceiverType(Selector selector, AbstractValue receiver) {
    _ensureFunctionSet();
    if (includesClosureCall(selector, receiver)) {
      return abstractValueDomain.dynamicType;
    }
    return _allFunctions.receiverType(selector, receiver, abstractValueDomain);
  }

  Iterable<MemberEntity> locateMembers(
      Selector selector, AbstractValue receiver) {
    _ensureFunctionSet();
    return _allFunctions.filter(selector, receiver, abstractValueDomain);
  }

  bool hasAnyUserDefinedGetter(Selector selector, AbstractValue receiver) {
    _ensureFunctionSet();
    return _allFunctions
        .filter(selector, receiver, abstractValueDomain)
        .any((each) => each.isGetter);
  }

  FieldEntity locateSingleField(Selector selector, AbstractValue receiver) {
    MemberEntity result = locateSingleMember(selector, receiver);
    return (result != null && result.isField) ? result : null;
  }

  MemberEntity locateSingleMember(Selector selector, AbstractValue receiver) {
    if (includesClosureCall(selector, receiver)) {
      return null;
    }
    receiver ??= abstractValueDomain.dynamicType;
    return abstractValueDomain.locateSingleMember(receiver, selector);
  }

  AbstractValue extendMaskIfReachesAll(
      Selector selector, AbstractValue receiver) {
    bool canReachAll = true;
    if (receiver != null) {
      canReachAll = backendUsage.isInvokeOnUsed &&
          abstractValueDomain.needsNoSuchMethodHandling(receiver, selector);
    }
    return canReachAll ? abstractValueDomain.dynamicType : receiver;
  }

  bool fieldNeverChanges(MemberEntity element) {
    if (!element.isField) return false;
    if (nativeData.isNativeMember(element)) {
      // Some native fields are views of data that may be changed by operations.
      // E.g. node.firstChild depends on parentNode.removeBefore(n1, n2).
      // TODO(sra): Refine the effect classification so that native effects are
      // distinct from ordinary Dart effects.
      return false;
    }

    if (!element.isAssignable) {
      return true;
    }
    if (element.isInstanceMember) {
      return !assignedInstanceMembers.contains(element);
    }
    return false;
  }

  @override
  String dump([ClassEntity cls]) {
    StringBuffer sb = new StringBuffer();
    if (cls != null) {
      sb.write("Classes in the closed world related to $cls:\n");
    } else {
      sb.write("Instantiated classes in the closed world:\n");
    }
    getClassHierarchyNode(commonElements.objectClass)
        .printOn(sb, ' ', instantiatedOnly: cls == null, withRespectTo: cls);
    return sb.toString();
  }

  /// Should only be called by subclasses.
  void addClassHierarchyNode(ClassEntity cls, ClassHierarchyNode node) {
    _classHierarchyNodes[cls] = node;
  }

  /// Should only be called by subclasses.
  void addClassSet(ClassEntity cls, ClassSet classSet) {
    _classSets[cls] = classSet;
  }
}

abstract class ClosedWorldRtiNeedMixin implements KClosedWorld {
  RuntimeTypesNeed _rtiNeed;

  void computeRtiNeed(ResolutionWorldBuilder resolutionWorldBuilder,
      RuntimeTypesNeedBuilder rtiNeedBuilder, CompilerOptions options) {
    _rtiNeed = rtiNeedBuilder.computeRuntimeTypesNeed(
        resolutionWorldBuilder, this, options);
  }

  RuntimeTypesNeed get rtiNeed => _rtiNeed;
}

abstract class KClosedWorld {
  DartTypes get dartTypes;
  KAllocatorAnalysis get allocatorAnalysis;
  BackendUsage get backendUsage;
  NativeData get nativeData;
  InterceptorData get interceptorData;
  ElementEnvironment get elementEnvironment;
  CommonElements get commonElements;
  ClassHierarchy get classHierarchy;

  /// Returns `true` if [cls] is implemented by an instantiated class.
  bool isImplemented(ClassEntity cls);

  Iterable<MemberEntity> get liveInstanceMembers;
  Map<ClassEntity, Set<ClassEntity>> get mixinUses;
  Map<ClassEntity, Set<ClassEntity>> get typesImplementedBySubclasses;

  /// Members that are written either directly or through a setter selector.
  Iterable<MemberEntity> get assignedInstanceMembers;

  Iterable<ClassEntity> get liveNativeClasses;
  Iterable<MemberEntity> get processedMembers;
  RuntimeTypesNeed get rtiNeed;
  NoSuchMethodData get noSuchMethodData;
}
