// Copyright 2018 The Sponge authors.
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

import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/bloc/provide_action_args_state.dart';
import 'package:sponge_flutter_api/src/common/ui/base_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/ui_context.dart';
import 'package:sponge_flutter_api/src/util/utils.dart';
import 'package:sponge_grpc_client_dart/sponge_grpc_client_dart.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

class ActionCallViewModel extends BaseViewModel {
  ActionCallViewModel(this.actionData);

  ActionData actionData;
  Map<String, ProvidedValue> providedArgs = {};
}

abstract class ActionCallView extends BaseView {
  void refresh();
  Future<void> refreshArgs({bool modal});
  Future<bool> saveForm();
  Future<void> onBeforeSubActionCall();
  Future<void> onAfterSubActionCall(ActionCallState state);
}

class _Dependencies {
  _Dependencies(this.actionData);

  final ActionData actionData;
  Map<String, Set<String>> _reverseDependencies;

  Map<String, Set<String>> get reverseDependencies {
    _reverseDependencies ??= _createReverseDependencies();
    return _reverseDependencies;
  }

  void rebuild() => _reverseDependencies = _createReverseDependencies();

  Map<String, Set<String>> _createReverseDependencies() {
    Map<String, Set<String>> reverseDependencies = {};
    actionData.traverseArguments(
        (qType) => reverseDependencies[qType.path] = Set(),
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

class ActionCallPresenter
    extends BasePresenter<ActionCallViewModel, ActionCallView>
    implements UiContextCallbacks {
  ActionCallPresenter(ActionCallViewModel viewModel, ActionCallView view)
      : super(viewModel, view);

  static final Logger _logger = Logger('ActionCallPresenter');
  bool busy = false;
  //final Lock _lock = Lock(reentrant: true);
  bool get callable => actionMeta.callable ?? true;
  _Dependencies _dependencies;
  bool _actionPrepared = false;
  bool _running = true;

  List<String> _refreshEvents;
  ClientSubscription _eventSubscription;

  final Map<String, dynamic> _argsToSubmit = {};

  bool _anyArgSavedOrUpdated = false;
  bool get anyArgSavedOrUpdated => _anyArgSavedOrUpdated;

  dynamic error;

  List<QualifiedDataType> _getQualifiedTypes() {
    List<QualifiedDataType> qualifiedTypes = [];
    actionData.traverseArguments(
        (QualifiedDataType qType) => qualifiedTypes.add(qType),
        namedOnly: false);
    return qualifiedTypes;
  }

  void init() {
    _prepareArgs();
    _initEventSubscription();
  }

  void _initEventSubscription() {
    _refreshEvents ??= Features.getStringList(
        actionData.actionMeta.features, Features.ACTION_REFRESH_EVENTS);

    if (_refreshEvents.isNotEmpty &&
        service.spongeService.grpcClient != null &&
        _eventSubscription == null) {
      _eventSubscription =
          service.spongeService.grpcClient.subscribe(_refreshEvents);
      _eventSubscription.eventStream.listen((event) async {
        if (_running) {
          await view.refreshArgs(modal: false);
        }
      }, onError: (e) {
        _logger.severe('Event subscription error', e);
      });
    }
  }

  void ensureRunning() {
    _ensureEventSubscription();
  }

  void _ensureEventSubscription() {
    if (_eventSubscription == null) {
      return;
    }

    if (!_eventSubscription.subscribed) {
      // Renew a subscription if necessary in case of an error.
      _eventSubscription = null;
      _initEventSubscription();
    }
  }

  void _prepareArgs({bool force = false}) {
    if (!_actionPrepared || force) {
      this.service.spongeService.prepareActionByIntent(actionData);
      _actionPrepared = true;
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

  Stream<ProvideActionArgsState> provideArgs() async* {
    yield* _provideArgs(
        (qType) => !viewModel.providedArgs.containsKey(qType.path));
  }

  Future<bool> refreshAllowedProvidedArgs() async {
    await _provideArgs((qType) =>
        qType.type.provided.readOnly || qType.type.provided.overwrite).drain();

    return true;
  }

  Stream<ProvideActionArgsState> _provideArgs(
      bool filter(QualifiedDataType qType),
      {Map<String, Map<String, Object>> features}) async* {
    //return await _lock.synchronized(() async {
    _dependencies ??= _Dependencies(actionData);
    _dependencies.rebuild();

    _logger
        .finest('Reverse dependencies: ${_dependencies.reverseDependencies}');

    features ??= {};

    List<String> namesToProvide;

    bool emitted = false;
    // Try to get all available provided values including that with dependencies.
    while (true) {
      List<String> newNamesToProvide = [];

      _getQualifiedTypes().forEach((qType) {
        if (DataTypeUtils.isProvidedRead(qType.type) &&
            _dependencies.hasDependenciesResolved(qType,
                unresolvedPaths: newNamesToProvide) &&
            qType.type.provided.mode != ProvidedMode.IMPLICIT &&
            filter(qType)) {
          if (qType.path != null) {
            newNamesToProvide.add(qType.path);
          }
        }
      });

      if ((newNamesToProvide.isEmpty ||
              ListEquality().equals(newNamesToProvide, namesToProvide)) &&
          _argsToSubmit.isEmpty) {
        if (!emitted) {
          yield ProvideActionArgsStateNoInvocation();
        }
        return;
      }

      // Set pageable info if necessary.
      _setupPageableListsFeatures(newNamesToProvide, features);

      namesToProvide = newNamesToProvide;

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

      // TODO predefined doesn't support Dynamic values.
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
          'Provide (${actionMeta.name}): $namesToProvide, submit: ${actualArgsToSubmit.keys}, current: $current, dynamicTypes: $dynamicTypes, features: $features, loading: $loading');

      Map<String, ProvidedValue> newProvidedArgs = await service
          .spongeService.client
          .provideActionArgs(actionData.actionMeta.name,
              provide: namesToProvide,
              submit: List.of(actualArgsToSubmit.keys),
              current: current,
              dynamicTypes: dynamicTypes,
              features: features);

      // _logger.fine('\t-> provided: ${newProvidedArgs.keys}');

      var previousViewModelProvidedArgs = Map.from(viewModel.providedArgs);
      viewModel.providedArgs.addAll(newProvidedArgs);

      var preserveDependencies = Set.of(newProvidedArgs.keys);
      newProvidedArgs.forEach((name, argValue) {
        var argType = actionData.getArgType(name);
        if (argType.provided != null && (argValue?.valuePresent ?? false)) {
          // Verify the returned provided values.
          if (argType.provided.readOnly ||
              argType.provided.overwrite ||
              actionData.getArgValueByName(name, unwrapAnnotatedTarget: true) ==
                  null ||
              !previousViewModelProvidedArgs.containsKey(name)) {
            _setArg(name, argValue.value,
                preserveDependencies: preserveDependencies);
          } else {
            _logger.warning(
                'Unexpected provided values for ${actionMeta.name}/${argType.name}');
          }
        }
      });

      _dependencies.rebuild();

      // Update pageable lists.
      _updatePageableLists(newProvidedArgs);

      yield ProvideActionArgsStateAfterInvocation();
      emitted = true;
    }
    //});
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

  void _setupPageableListsFeatures(
      List<String> argNames, Map<String, Map<String, Object>> features) {
    Set<String> pageableListArgTypes = argNames
        .where((argName) => actionData.isArgPageableList(argName))
        .toSet()
          ..addAll(actionData.getProvidedOptionalPageableListArgNames());

    pageableListArgTypes.forEach((argName) {
      var pageableList = actionData.getPageableList(argName);
      if (pageableList != null) {
        if (!pageableList.initialized) {
          int offset = _getProvideFeature(
              features, argName, Features.PROVIDE_VALUE_OFFSET);
          if (offset == null) {
            _setProvideFeature(
                features, argName, Features.PROVIDE_VALUE_OFFSET, 0);
          }

          int limit = _getProvideFeature(
              features, argName, Features.PROVIDE_VALUE_LIMIT);
          if (limit == null) {
            _setProvideFeature(features, argName, Features.PROVIDE_VALUE_LIMIT,
                service.settings.defaultPageableListPageSize);
          }
        } else {
          int offset = _getProvideFeature(
              features, argName, Features.PROVIDE_VALUE_OFFSET);
          if (offset == null) {
            _setProvideFeature(
                features, argName, Features.PROVIDE_VALUE_OFFSET, 0);
          }

          // A hack to fetch one big page to preserve a consistency of the list state from the server. Can be resource consuming!
          int limit = _getProvideFeature(
              features, argName, Features.PROVIDE_VALUE_LIMIT);
          if (limit == null) {
            limit = pageableList.limit != null &&
                    pageableList.limit > pageableList.length
                ? pageableList.limit
                : pageableList.length;
            _setProvideFeature(
                features, argName, Features.PROVIDE_VALUE_LIMIT, limit);
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

  String get connectionName => service.spongeService?.connection?.name;

  ActionData get actionData => viewModel.actionData;

  ActionMeta get actionMeta => actionData.actionMeta;

  String get actionLabel => getActionMetaDisplayLabel(actionData.actionMeta);

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
          viewModel.providedArgs.remove(dependentName);
        }
      });
    }
  }

  void clearArgs() {
    actionData.clear(clearReadOnly: false);
    _prepareArgs(force: true);
    viewModel.providedArgs = {};

    // Clear globally saved action args and result.
    service.spongeService.getCachedAction(actionMeta.name).clear();

    _anyArgSavedOrUpdated = true;
  }

  bool get hasProvidedArgs =>
      actionMeta.args.any((argType) => argType.provided != null);

  bool get hasRefreshableArgs => actionMeta.args.any((argType) =>
      DataTypeUtils.isProvidedRead(argType) &&
      (argType.provided.readOnly || argType.provided.overwrite));

  void validateArgs() => service.spongeService.client
      .validateCallArgs(actionMeta, actionData.args);

  bool get showCall => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_SHOW_CALL, () => true);

  bool get showRefresh => Features.getOptional(
      actionMeta.features,
      Features.ACTION_CALL_SHOW_REFRESH,
      () => actionMeta.features[Features.ACTION_CALL_REFRESH_LABEL] != null);

  bool get showClear => Features.getOptional(
      actionMeta.features,
      Features.ACTION_CALL_SHOW_CLEAR,
      () => actionMeta.features[Features.ACTION_CALL_CLEAR_LABEL] != null);

  bool get showCancel => Features.getOptional(
      actionMeta.features,
      Features.ACTION_CALL_SHOW_CANCEL,
      () => actionMeta.features[Features.ACTION_CALL_CANCEL_LABEL] != null);

  String get callLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_CALL_LABEL, () => 'RUN');

  String get refreshLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_REFRESH_LABEL, () => 'REFRESH');

  String get clearLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_CLEAR_LABEL, () => 'CLEAR');

  String get cancelLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_CANCEL_LABEL, () => 'CANCEL');

  dynamic _normalizeValue(DataType type, value) {
    if (value is String && value.isEmpty) {
      value = null;
    }

    // TODO What about a dynamic value?

    return ((type?.annotated ?? false) && !(value is AnnotatedValue))
        ? AnnotatedValue(value)
        : value;
  }

  void close() {
    _running = false;
    _eventSubscription?.close();
  }

  bool isScrollable() {
    return !actionMeta.args.any((arg) => hasListTypeScroll(arg));
  }

  Future<bool> isActionActive() async =>
      await service.spongeService.isActionActive(actionMeta.name);

  // Callbacks.
  void _onSaveOrUpdate(
      QualifiedDataType qType, dynamic value, bool refreshView) {
    if (qType.type != null) {
      value = _normalizeValue(qType.type, value);
      _setArg(qType.path, value);

      if ((qType.type.provided?.submittable != null) && qType.path != null) {
        _argsToSubmit[qType.path] = value;
      }

      if (refreshView) {
        view.refresh();
      }
    }
  }

  @override
  void onSave(QualifiedDataType qType, dynamic value) {
    _onSaveOrUpdate(qType, value, true);
  }

  @override
  void onUpdate(QualifiedDataType qType, dynamic value) {
    bool responsive = DataTypeUtils.getFeatureOrProperty(
        qType.type, value, Features.RESPONSIVE, () => false);

    _onSaveOrUpdate(qType, value, responsive);
  }

  @override
  void onActivate(QualifiedDataType qType, value) {
    if ((qType.type.provided?.submittable != null) && qType.path != null) {
      _argsToSubmit[qType.path] = value;

      view.refresh();
    }
  }

  @override
  ProvidedValue onGetProvidedArg(QualifiedDataType qType) =>
      viewModel.providedArgs != null
          ? viewModel.providedArgs[qType.path]
          : null;

  @override
  bool shouldBeEnabled(QualifiedDataType qType) {
    return qType.type?.provided == null ||
        _dependencies.hasDependenciesResolved(qType);
  }

  @override
  Future<void> onRefresh() async => view.refresh();

  @override
  Future<void> onRefreshArgs() async {
    await view.refreshArgs();
  }

  @override
  Future<bool> onSaveForm() async => await view.saveForm();

  @override
  Future<void> onBeforeSubActionCall() async {
    await view.onBeforeSubActionCall();
  }

  @override
  Future<void> onAfterSubActionCall(ActionCallState state) async {
    await view.onAfterSubActionCall(state);
  }

  @override
  PageableList getPageableList(QualifiedDataType qType) =>
      actionData.getPageableList(qType.path);

  @override
  Future<void> fetchPageableListPage(QualifiedDataType listQType) async {
    var pageableList = actionData.getPageableList(listQType.path);
    if (pageableList.hasMorePages) {
      await _provideArgs((qType) => qType.path == listQType.path, features: {
        listQType.path: {
          Features.PROVIDE_VALUE_OFFSET: (pageableList.length ?? 0),
          Features.PROVIDE_VALUE_LIMIT: (pageableList.limit ??
              service.settings.defaultPageableListPageSize)
        }
      }).drain();
    }
  }

  @override
  String getKey(String code) {
    if (code == null) {
      return null;
    }

    try {
      return actionData.getArgValueByName(code,
          unwrapAnnotatedTarget: true, unwrapDynamicTarget: true);
    } catch (e) {
      // TODO Handle the exception properly.
      _logger.severe('getKey error for \'$code\'', e);
      return null;
    }
  }
}
