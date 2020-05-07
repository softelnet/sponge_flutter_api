// Copyright 2020 The Sponge authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/provide_action_args_state.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';
import 'package:sponge_flutter_api/src/common/util/common_utils.dart';
import 'package:sponge_flutter_api/src/flutter/model/flutter_model.dart';
import 'package:sponge_grpc_client_dart/sponge_grpc_client_dart.dart';

typedef ProvideArgsFilterCallback = bool Function(QualifiedDataType qType);
typedef OnEventReceivedCallback = FutureOr<void> Function(RemoteEvent event);

enum ProvideActionArgsDemand { provideArgs, refreshAllowedProvidedArgs }

class ProvideActionArgsBloc
    extends Bloc<ProvideActionArgsDemand, ProvideActionArgsState> {
  ProvideActionArgsBloc({
    @required ActionCallSession session,
    ProvideActionArgsState initialState,
  })  : _session = session,
        _initialState = initialState ?? ProvideActionArgsStateInitialize();

  final ActionCallSession _session;
  final ProvideActionArgsState _initialState;

  @override
  ProvideActionArgsState get initialState => _initialState;

  @override
  Stream<ProvideActionArgsState> mapEventToState(
      ProvideActionArgsDemand demand) {
    return _session.provideArgs(demand);
  }

  void provideArgs() => add(ProvideActionArgsDemand.provideArgs);

  // Emits a state in the provide args BLoC.
  void refreshAllowedProvidedArgs() =>
      add(ProvideActionArgsDemand.refreshAllowedProvidedArgs);
}

class ActionCallSession {
  ActionCallSession(
    this.spongeService,
    this.actionData, {
    int defaultPageableListPageSize,
    bool verifyIsActive,
  })  : _defaultPageableListPageSize = defaultPageableListPageSize ?? 20,
        _verifyIsActive = verifyIsActive ?? true;

  static final Logger _logger = Logger('ActionCallSession');

  final SpongeService spongeService;
  final ActionData actionData;

  ActionArgDependencies _dependencies;

  bool _actionPrepared = false;

  bool _running = false;

  final bool _verifyIsActive;
  bool _isActive;

  ProvideActionArgsBloc _provideArgsBloc;
  ProvideActionArgsBloc get provideArgsBloc => _provideArgsBloc;

  bool _initialProvideArgs = true;
  Map<String, ProvidedValue> _providedArgs;

  final Map<String, dynamic> _argsToSubmit = {};

  bool _anyArgSavedOrUpdated = false;
  bool get anyArgSavedOrUpdated => _anyArgSavedOrUpdated;

  List<String> _refreshEvents;
  ClientSubscription _eventSubscription;

  final int _defaultPageableListPageSize;

  bool _isRefreshAllowedProvidedArgsPending = false;

  ActionMeta get actionMeta => actionData.actionMeta;

  void open() {
    if (_running) {
      return;
    }

    _prepareArgs();
    _initArgsProvidedEarlier();

    _initEventSubscription();

    _dependencies = ActionArgDependencies(actionData)..rebuild();

    _provideArgsBloc = ProvideActionArgsBloc(session: this);

    // Initially provide args.
    _provideArgsBloc.provideArgs();

    _running = true;
  }

  void close() {
    _running = false;
    _eventSubscription?.close();
  }

  Future<bool> isActionActive() async {
    // Cache the active/inactive flag.
    _isActive ??= (!_verifyIsActive || !actionMeta.activatable)
        ? true
        : await spongeService.isActionActive(actionMeta.name);

    return _isActive;
  }

  void _prepareArgs({bool force = false}) {
    if (!_actionPrepared || force) {
      spongeService.prepareActionByIntent(actionData);
      _actionPrepared = true;
    }
  }

  /// Init top level args that have been provided earlier.
  void _initArgsProvidedEarlier() {
    _providedArgs = {};

    _getQualifiedTypes()
        .where((qType) => qType.path != null && qType.type.provided != null)
        .where((qType) =>
            qType.type.provided != null && !qType.type.provided.overwrite)
        .forEach((qType) {
      var value = actionData.getArgValueByName(qType.path,
          unwrapAnnotatedTarget: false, unwrapDynamicTarget: false);

      ProvidedValue oldProvidedValue = actionData.providedValues[qType.path];

      // If a value has been provided and set earlier, reuse the merged provided value.
      if (!DataTypeUtils.isValueNotSet(value) && oldProvidedValue != null) {
        _providedArgs[qType.path] = ProvidedValue(
          value: value,
          valuePresent: true,
          annotatedValueSet: oldProvidedValue.annotatedValueSet,
          annotatedElementValueSet: oldProvidedValue.annotatedElementValueSet,
        );
      }
    });
  }

  Stream<ProvideActionArgsState> _provideArgs(
    ProvideArgsFilterCallback filter, {
    Map<String, Map<String, Object>> argFeatures,
    bool errorsAsStates = true,
  }) async* {
    try {
      _dependencies.rebuild();

      argFeatures ??= {};

      Set<String> namesProvided = {};

      bool stateEmitted = false;
      // Try to get all available provided values including that with dependencies.
      while (true) {
        var namesToProvide = <String>[];

        _getQualifiedTypes().forEach((qType) {
          if (!namesProvided.contains(qType.path) &&
              DataTypeUtils.isProvidedRead(qType.type) &&
              _dependencies.hasDependenciesResolved(qType,
                  unresolvedPaths: namesToProvide) &&
              qType.type.provided.mode != ProvidedMode.IMPLICIT &&
              filter(qType)) {
            if (qType.path != null) {
              namesToProvide.add(qType.path);
            }
          }
        });

        if (namesToProvide.isEmpty && _argsToSubmit.isEmpty) {
          if (!stateEmitted) {
            yield ProvideActionArgsStateNoInvocation();
          }

          return;
        }

        // Set pageable info if necessary.
        _setupPageableListsFeatures(namesToProvide, argFeatures);

        Set<String> currentNames = namesToProvide.expand((argName) {
          var arg = actionData.getArgType(argName);

          return arg.provided.current
              ? arg.provided.dependencies + [argName]
              : arg.provided.dependencies;
        }).toSet()
          ..addAll(_getCurrentArgNamesForSubmit());

        // Save a copy and clear the original before a network call.
        var actualArgsToSubmit = Map.of(_argsToSubmit);
        _argsToSubmit.clear();

        // TODO The predefined doesn't support Dynamic values.
        var current =
            actionData.getArgMap(currentNames, predefined: actualArgsToSubmit);
        var dynamicTypes = actionData.getDynamicTypeNestedTypes(
            List.of(namesToProvide)..addAll(currentNames));

        // Arguments influenced by the submitted arguments (their values can be provided not explicitly).
        var influencedBySummitted = actualArgsToSubmit.keys
            .expand((submit) =>
                actionData.getArgType(submit).provided.submittable.influences)
            .toList();

        var loading = namesToProvide + influencedBySummitted;

        yield ProvideActionArgsStateBeforeInvocation(loading: loading);

        _logger.finer(
            'Provide (${actionMeta.name}): $namesToProvide, submit: ${actualArgsToSubmit.keys}, current: $current, dynamicTypes: $dynamicTypes, argFeatures: $argFeatures, loading: $loading');

        Map<String, ProvidedValue> newProvidedArgs =
            await spongeService.client.provideActionArgs(
          actionData.actionMeta.name,
          provide: namesToProvide,
          submit: List.of(actualArgsToSubmit.keys),
          current: current,
          dynamicTypes: dynamicTypes,
          argFeatures: argFeatures,
          initial: _initialProvideArgs,
        );

        _initialProvideArgs = false;

        _logger.finest('\t-> provided: ${newProvidedArgs.keys}');

        _providedArgs.addAll(newProvidedArgs);

        // Update provided values in the ActionData as well.
        actionData.providedValues.addAll(newProvidedArgs);

        var preserveDependencies = Set.of(newProvidedArgs.keys);
        newProvidedArgs.forEach((name, argValue) {
          namesProvided.add(name);

          var argType = actionData.getArgType(name);
          if (argType.provided != null && (argValue?.valuePresent ?? false)) {
            _setArg(name, argValue.value,
                preserveDependencies: preserveDependencies);
          }
        });

        _dependencies.rebuild();

        // Update pageable lists.
        _updatePageableLists(newProvidedArgs);

        yield ProvideActionArgsStateAfterInvocation();
        stateEmitted = true;
      }
    } catch (e) {
      _logger.severe('Provide args error', e);

      if (errorsAsStates) {
        yield ProvideActionArgsStateError(e);
      } else {
        rethrow;
      }
    }
  }

  Set<String> _getCurrentArgNamesForSubmit() {
    Set<String> currentNames = Set.from(_argsToSubmit.keys);
    _argsToSubmit.keys.forEach((argName) {
      var dependencies = actionData.getArgType(argName).provided?.dependencies;
      if (dependencies != null) {
        currentNames.addAll(dependencies);
      }
    });

    return currentNames;
  }

  bool _isArgForRefreshAllowedProvidedArgs(QualifiedDataType qType) =>
      qType.type.readOnly || qType.type.provided.overwrite;

  Stream<ProvideActionArgsState> provideArgs(
      ProvideActionArgsDemand demand) async* {
    switch (demand) {
      case ProvideActionArgsDemand.provideArgs:
        yield* _provideArgs((qType) => !_providedArgs.containsKey(qType.path));

        if (_isRefreshAllowedProvidedArgsPending) {
          // TODO refreshAllowedProvidedArgs errors aren't propagated to GUI.
          await refreshAllowedProvidedArgsSilently(supressErrors: true);

          yield ProvideActionArgsStateAfterInvocation();
        }
        break;
      case ProvideActionArgsDemand.refreshAllowedProvidedArgs:
        // TODO refreshAllowedProvidedArgs errors aren't propagated to GUI.
        await refreshAllowedProvidedArgsSilently(supressErrors: true);

        yield ProvideActionArgsStateAfterInvocation();

        break;
    }
  }

  // Doesn't emit any state in the provide args BLoC.
  Future<bool> refreshAllowedProvidedArgsSilently(
      {bool supressErrors = false}) async {
    _isRefreshAllowedProvidedArgsPending = false;

    await _provideArgs((qType) => _isArgForRefreshAllowedProvidedArgs(qType),
            errorsAsStates: supressErrors)
        .drain();

    return true;
  }

  void ensureRunning() {
    _ensureEventSubscription();
  }

  void clearArgs() {
    actionData.clear(clearReadOnly: false);
    _prepareArgs(force: true);
    _providedArgs = {};

    // Clear globally saved action args and result.
    spongeService.getCachedAction(actionMeta.name).clear();

    // Clear action bloc.
    spongeService.getActionCallBloc(actionMeta.name)?.clear();

    _anyArgSavedOrUpdated = true;

    _provideArgsBloc.provideArgs();
  }

  List<QualifiedDataType> _getQualifiedTypes() {
    var qualifiedTypes = <QualifiedDataType>[];
    actionData.traverseArguments(
      (QualifiedDataType qType) => qualifiedTypes.add(qType),
      namedOnly: false,
    );
    return qualifiedTypes;
  }

  void _updatePageableLists(Map<String, ProvidedValue> newProvidedArgs) {
    newProvidedArgs.forEach((argName, providedValue) {
      if (actionData.isArgPageableList(argName) &&
          providedValue.valuePresent &&
          providedValue.value != null) {
        actionData.getPageableList(argName)?.addPage(providedValue.value);
      }
    });
  }

  bool saveOrUpdate(QualifiedDataType qType, dynamic value) {
    if (qType.type != null) {
      value = _normalizeValue(qType.type, value);
      _setArg(qType.path, value);

      if ((qType.type.provided?.submittable != null) && qType.path != null) {
        _argsToSubmit[qType.path] = value;
      }

      return true;
    }

    return false;
  }

  bool activate(QualifiedDataType qType, value) {
    if ((qType.type.provided?.submittable != null) && qType.path != null) {
      _argsToSubmit[qType.path] = value;
      _provideArgsBloc.provideArgs();

      return true;
    }

    return false;
  }

  ProvidedValue getProvidedArg(QualifiedDataType qType) =>
      _providedArgs != null ? _providedArgs[qType.path] : null;

  bool shouldBeEnabled(QualifiedDataType qType) {
    return qType.type?.provided == null ||
        _dependencies.hasDependenciesResolved(qType);
  }

  void _setArg(String name, Object value, {Set<String> preserveDependencies}) {
    var oldValue = actionData.getArgValueByName(name);

    // GUI doesn't set an annotated valueLabel, valueDescription, typeLabel, typeDescription nor features.
    // For lazy update these values should be retained until the next arg provision.
    if (oldValue is AnnotatedValue &&
        value is AnnotatedValue &&
        // TODO Dynamic arg with annotated is not supported, will throw an exception.
        (actionData.getArgType(name).provided?.lazyUpdate ?? false)) {
      value.updateIfAbsent(oldValue);
    }

    actionData.setArgValueByName(name, value);
    if (!DataTypeUtils.equalsValue(oldValue, value)) {
      _anyArgSavedOrUpdated = true;
      _clearDependencies(name, preserveDependencies: preserveDependencies);
    }
  }

  void _clearDependencies(String name, {Set<String> preserveDependencies}) {
    if (_dependencies != null) {
      var argsThatDependOnThis = _dependencies.reverseDependencies[name];

      // TODO Dependencies for dynamic types are not implemented.

      // For a dynamic type argsThatDependOnThis can be null.
      argsThatDependOnThis?.forEach((dependentName) {
        if (!(preserveDependencies?.contains(dependentName) ?? false)) {
          // Clear the arguments that depend on this if not lazy.
          if (!(actionData.getArgType(dependentName).provided?.lazyUpdate ??
              false)) {
            _setArg(dependentName, null,
                preserveDependencies: preserveDependencies);
          }
          // Set the arguments that depend on this to be provided from the server.
          _providedArgs.remove(dependentName);
        }
      });
    }
  }

  void _setupPageableListsFeatures(
      List<String> argNames, Map<String, Map<String, Object>> argFeatures) {
    Set<String> pageableListArgTypes = argNames
        .where((argName) => actionData.isArgPageableList(argName))
        .toSet()
          ..addAll(actionData.getProvidedOptionalPageableListArgNames());

    pageableListArgTypes.forEach((argName) {
      var pageableList = actionData.getPageableList(argName);
      if (pageableList != null) {
        if (!pageableList.initialized) {
          int offset = _getProvideFeature(
              argFeatures, argName, Features.PROVIDE_VALUE_OFFSET);
          if (offset == null) {
            _setProvideFeature(
                argFeatures, argName, Features.PROVIDE_VALUE_OFFSET, 0);
          }

          int limit = _getProvideFeature(
              argFeatures, argName, Features.PROVIDE_VALUE_LIMIT);
          if (limit == null) {
            _setProvideFeature(argFeatures, argName,
                Features.PROVIDE_VALUE_LIMIT, _defaultPageableListPageSize);
          }
        } else {
          int offset = _getProvideFeature(
              argFeatures, argName, Features.PROVIDE_VALUE_OFFSET);
          if (offset == null) {
            _setProvideFeature(
                argFeatures, argName, Features.PROVIDE_VALUE_OFFSET, 0);
          }

          // A hack to fetch one big page to preserve a consistency of the list state from the server. Can be resource consuming!
          int limit = _getProvideFeature(
              argFeatures, argName, Features.PROVIDE_VALUE_LIMIT);
          if (limit == null) {
            limit = pageableList.limit != null &&
                    pageableList.limit > pageableList.length
                ? pageableList.limit
                : pageableList.length;
            _setProvideFeature(
                argFeatures, argName, Features.PROVIDE_VALUE_LIMIT, limit);
          }
        }
      }
    });
  }

  dynamic _getProvideFeature(Map<String, Map<String, Object>> features,
          String argName, String featureName) =>
      features.containsKey(argName)
          ? (features[argName].containsKey(featureName)
              ? features[argName][featureName]
              : null)
          : null;

  void _setProvideFeature(Map<String, Map<String, Object>> features,
      String argName, String featureName, dynamic value) {
    if (!features.containsKey(argName)) {
      features[argName] = {};
    }

    features[argName][featureName] = value;
  }

  dynamic _normalizeValue(DataType type, value) {
    if (value is String) {
      value = CommonUtils.normalizeString(value);
    }

    // Normalize the annotated value.
    if (value is AnnotatedValue && value.value is String) {
      value.value = CommonUtils.normalizeString(value.value);
    }

    // TODO Handle a dynamic type value.

    // Wrap an annotated type value if not wrapped.
    return ((type?.annotated ?? false) && !(value is AnnotatedValue))
        ? AnnotatedValue(value)
        : value;
  }

  Future<void> fetchPageableListPage(QualifiedDataType listQType) async {
    var pageableList = actionData.getPageableList(listQType.path);
    if (pageableList.hasMorePages) {
      await _provideArgs((qType) => qType.path == listQType.path, argFeatures: {
        listQType.path: {
          Features.PROVIDE_VALUE_OFFSET: (pageableList.length ?? 0),
          Features.PROVIDE_VALUE_LIMIT:
              (pageableList.limit ?? _defaultPageableListPageSize)
        }
      }).drain();
    }
  }

  bool get hasProvidedArgs =>
      actionMeta.args.any((argType) => argType.provided != null);

  bool get hasRefreshableArgs => actionMeta.args.any((argType) =>
      DataTypeUtils.isProvidedRead(argType) &&
      (argType.readOnly || argType.provided.overwrite));

  // Events,
  void _initEventSubscription() {
    _refreshEvents ??= Features.getStringList(
        actionData.actionMeta.features, Features.ACTION_REFRESH_EVENTS);

    if (_refreshEvents.isNotEmpty &&
        spongeService.grpcClient != null &&
        _eventSubscription == null) {
      _eventSubscription = spongeService.grpcClient.subscribe(_refreshEvents);
      _eventSubscription.eventStream.listen((event) async {
        if (await _isRunningAndActive()) {
          _provideArgsBloc.refreshAllowedProvidedArgs();
        }
      }, onError: (e) async {
        if (await _isRunningAndActive()) {
          _logger.severe('Event subscription error', e);
          _provideArgsBloc.refreshAllowedProvidedArgs();
        }
      });
    }
  }

  Future<bool> _isRunningAndActive() async =>
      _running && await isActionActive();

  void _ensureEventSubscription() {
    if (_eventSubscription == null) {
      return;
    }

    if (!_eventSubscription.subscribed) {
      // Renew a subscription if necessary in case of an error.
      _eventSubscription = null;

      _isRefreshAllowedProvidedArgsPending = true;

      _provideArgsBloc.refreshAllowedProvidedArgs();

      _initEventSubscription();
    }
  }

  dynamic getAdditionalData(String path, String additionalDataKey) =>
      (actionData as FlutterActionData)
          .getAdditionalArgData(path, additionalDataKey);

  void setAdditionalData(String path, String additionalDataKey, dynamic value) {
    (actionData as FlutterActionData)
        .setAdditionalArgData(path, additionalDataKey, value);
  }
}

class ActionArgDependencies {
  ActionArgDependencies(this.actionData);

  final ActionData actionData;
  Map<String, Set<String>> _reverseDependencies;

  Map<String, Set<String>> get reverseDependencies {
    _reverseDependencies ??= _createReverseDependencies();
    return _reverseDependencies;
  }

  void rebuild() => _reverseDependencies = _createReverseDependencies();

  Map<String, Set<String>> _createReverseDependencies() {
    var reverseDependencies = <String, Set<String>>{};
    actionData.traverseArguments(
        (qType) => reverseDependencies[qType.path] = {},
        namedOnly: false);
    actionData.traverseArguments((qType) {
      qType.type.provided?.dependencies?.forEach(
          (dependency) => reverseDependencies[dependency].add(qType.path));
    }, namedOnly: false);

    // Set propagated nested dependencies.
    reverseDependencies.keys.forEach((dep) {
      var depElements = DataTypeUtils.getPathElements(dep);
      if (depElements.length > 1) {
        // Nested.
        Set<String> mirrorReverseDependencies = depElements
            .take(depElements.length - 1)
            .expand((d) => reverseDependencies[d] ?? <String>[])
            .toSet();
        reverseDependencies[dep].addAll(mirrorReverseDependencies);
      }
    });

    return reverseDependencies;
  }

  bool hasDependenciesResolved(QualifiedDataType qType,
      {List<String> unresolvedPaths}) {
    if (qType.type.provided == null) {
      return true;
    }

    if (!qType.type.provided.dependencies.every((dependency) {
      var dependencyMeta = actionData.getArgType(dependency);

      return (_isDependencySet(dependency, dependencyMeta) &&
              (unresolvedPaths == null ||
                  !unresolvedPaths.contains(dependency))) ||
          (dependencyMeta.provided != null &&
              dependencyMeta.provided.mode != ProvidedMode.EXPLICIT);
    })) {
      return false;
    }

    if (unresolvedPaths != null &&
        DataTypeUtils.getPathPaths(qType.path)
            .any((path) => unresolvedPaths.contains(path))) {
      return false;
    }

    return true;
  }

  bool _isDependencySet(String dependency, DataType dependencyMeta) {
    var value =
        actionData.getArgValueByName(dependency, unwrapAnnotatedTarget: true);
    // TODO Handle all nested types.

    // Handle nested records.
    if (dependencyMeta is RecordType) {
      if (!dependencyMeta.fields.every((field) =>
          DataTypeUtils.hasAllNotNullValuesSet(
              field, value != null ? value[field.name] : null))) {
        return false;
      }
    }

    return value != null || dependencyMeta.nullable;
  }
}
