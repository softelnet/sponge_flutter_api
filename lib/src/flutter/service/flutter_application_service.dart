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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/compatibility/compatibility_mobile.dart';
import 'package:sponge_flutter_api/src/flutter/configuration/preferences_configuration.dart';
import 'package:sponge_flutter_api/src/flutter/flutter_model.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/default_type_gui_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/external/painter.dart';
import 'package:sponge_flutter_api/src/util/utils.dart';

class FlutterApplicationService<S extends FlutterSpongeService>
    extends ApplicationService<S> {
  static final Logger _logger = Logger('FlutterApplicationService');
  SharedPreferences _prefs;
  DefaultTypeGuiProvider typeGuiProvider = DefaultTypeGuiProvider();
  final icons = MdiIcons();
  FlutterApplicationSettings get settings => super.settings;
  BuildContext _mainBuildContext;
  final Map<String, ActionIntentHandler> _actionIntentHandlers = {};

  Timer _subscriptionWatchdog;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    settings = FlutterApplicationSettings(_prefs);

    _initActionIntentHandlers();

    await configure(SharedPreferencesConnectionsConfiguration(_prefs),
        createTypeConverter(this),
        connectSynchronously: false);
  }

  void _initActionIntentHandlers() {
    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_LOGIN] =
        ActionIntentHandler(
      onBeforeCall: (ActionMeta actionMeta, List args) async {
        var usernameArg = getActionArgByIntent(
            actionMeta, Features.TYPE_INTENT_VALUE_USERNAME);
        Validate.notNull(usernameArg,
            'The action ${getActionMetaDisplayLabel(actionMeta)} should have the username argument');

        var passwordArg = getActionArgByIntent(
            actionMeta, Features.TYPE_INTENT_VALUE_PASSWORD);
        Validate.notNull(passwordArg,
            'The action ${getActionMetaDisplayLabel(actionMeta)} should have the password argument');

        var username = args[actionMeta.getArgIndex(usernameArg.name)];
        var password = args[actionMeta.getArgIndex(passwordArg.name)];

        await changeActiveConnectionCredentials(username, password);
      },
      onAfterCall: (ActionMeta actionMeta, List args,
          ActionCallResultInfo resultInfo) async {
        await spongeService.clearActions();
        ApplicationProvider.of(mainBuildContext)
            .updateConnection(spongeService.connection);
      },
      onCallError: (ActionMeta actionMeta, List args) async {
        // In case of error, set the connection to anonymous.
        await changeActiveConnectionCredentials(null, null);
      },
      onIsAllowed: (ActionMeta actionMeta) => !logged,
    );

    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_LOGOUT] =
        ActionIntentHandler(
      onAfterCall: (ActionMeta actionMeta, List args,
          ActionCallResultInfo resultInfo) async {
        await changeActiveConnectionCredentials(null, null);

        await spongeService.clearActions();
        ApplicationProvider.of(mainBuildContext)
            .updateConnection(spongeService.connection);
      },
      onCallError: (ActionMeta actionMeta, List args) async {
        await spongeService.clearActions();
        // In case of error, set the connection to anonymous.
        await changeActiveConnectionCredentials(null, null);

        ApplicationProvider.of(mainBuildContext)
            .updateConnection(spongeService.connection);
      },
      onIsAllowed: (ActionMeta actionMeta) => logged,
    );

    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_SIGN_UP] =
        ActionIntentHandler(
      onIsAllowed: (ActionMeta actionMeta) => !logged,
    );

    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_SUBSCRIPTION] =
        ActionIntentHandler(
      onPrepare: (ActionMeta actionMeta, List args) {
        args[_getSubscribeEventNamesActionArgIndex(actionMeta)] =
            activeConnection?.subscriptionEventNames ?? [];
        args[_getSubscribeSubscribeActionArgIndex(actionMeta)] =
            activeConnection?.subscribe ?? false;
      },
      onAfterCall: (ActionMeta actionMeta, List args,
          ActionCallResultInfo resultInfo) async {
        // Get the event names argument.
        var eventNamesArg =
            args[_getSubscribeEventNamesActionArgIndex(actionMeta)];
        Validate.isTrue(eventNamesArg is List,
            'The action ${getActionMetaDisplayLabel(actionMeta)} ${Features.TYPE_INTENT_VALUE_EVENT_NAMES} argument value should be a list');

        // Get the subscribe argument.
        var subscribeArg =
            args[_getSubscribeSubscribeActionArgIndex(actionMeta)];
        Validate.isTrue(subscribeArg is bool,
            'The action ${getActionMetaDisplayLabel(actionMeta)} ${Features.TYPE_INTENT_VALUE_SUBSCRIBE} argument value should be a boolean');

        // Modify the subscription configuration.
        await changeActiveConnectionSubscription(
            (eventNamesArg as List)?.cast(), subscribeArg as bool);

        // Subscribe.
        await subscribe(spongeService);
      },
    );

    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_RELOAD] =
        ActionIntentHandler(
      onAfterCall: (ActionMeta actionMeta, List args,
              ActionCallResultInfo resultInfo) async =>
          await _reset(),
    );

    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_RESET] =
        ActionIntentHandler(
      onAfterCall: (ActionMeta actionMeta, List args,
              ActionCallResultInfo resultInfo) async =>
          await _reset(),
    );
  }

  Future<void> _reset() async {
    await spongeService.clearActions();
    ApplicationProvider.of(mainBuildContext)
        .updateConnection(spongeService.connection, force: true);
  }

  int _getSubscribeEventNamesActionArgIndex(ActionMeta actionMeta) {
    DataType eventNamesType = getActionArgByIntent(
        actionMeta, Features.TYPE_INTENT_VALUE_EVENT_NAMES);
    Validate.notNull(eventNamesType,
        'The action ${getActionMetaDisplayLabel(actionMeta)} should have the ${Features.TYPE_INTENT_VALUE_EVENT_NAMES} argument');
    Validate.isTrue(
        eventNamesType is ListType && eventNamesType.elementType is StringType,
        'The action ${getActionMetaDisplayLabel(actionMeta)} ${Features.TYPE_INTENT_VALUE_EVENT_NAMES} argument type should be a list of strings');
    return actionMeta.getArgIndex(eventNamesType.name);
  }

  int _getSubscribeSubscribeActionArgIndex(ActionMeta actionMeta) {
    DataType subscribeType =
        getActionArgByIntent(actionMeta, Features.TYPE_INTENT_VALUE_SUBSCRIBE);
    Validate.notNull(subscribeType,
        'The action ${getActionMetaDisplayLabel(actionMeta)} should have the ${Features.TYPE_INTENT_VALUE_SUBSCRIBE} argument');
    Validate.isTrue(subscribeType is BooleanType,
        'The action ${getActionMetaDisplayLabel(actionMeta)} ${Features.TYPE_INTENT_VALUE_SUBSCRIBE} argument type should be a boolean');
    return actionMeta.getArgIndex(subscribeType.name);
  }

  // TODO BuildContext to service.
  void bindMainBuildContext(BuildContext mainBuildContext) {
    _mainBuildContext = mainBuildContext;
  }

  BuildContext get mainBuildContext => _mainBuildContext;

  UnitTypeGuiProvider getTypeGuiProvider(DataType type) =>
      typeGuiProvider.getProvider(type);

  @override
  Future<S> createSpongeService(
      SpongeConnection connection, TypeConverter typeConverter) async {
    var service =
        FlutterSpongeService(connection, typeConverter, typeGuiProvider);

    return service;
  }

  Future<void> configureSpongeService(
      FlutterSpongeService spongeService) async {
    spongeService.maxEventCount = settings.maxEventCount;
    spongeService.autoUseAuthToken = settings.autoUseAuthToken;
    spongeService.actionIntentHandlers = _actionIntentHandlers;
  }

  @override
  Future<void> startSpongeService(FlutterSpongeService spongeService) async {
    await super.startSpongeService(spongeService);

    // Subscribe but don't block the current thread.
    unawaited(subscribe(spongeService));
  }

  @override
  Future<void> changeActiveConnectionCredentials(
      String username, String password) async {
    await super.changeActiveConnectionCredentials(username, password);

    // Resubscribe.
    await subscribe(spongeService);
  }

  Future<void> subscribe(SpongeService spongeService) async {
    _subscriptionWatchdog?.cancel();
    _subscriptionWatchdog = null;

    if (activeConnection.subscribe) {
      try {
        try {
          var subscription = await spongeService.subscribe();
          if (subscription != null) {
            subscription.eventStream.listen(
              (event) async {
                try {
                  if (subscription.subscribed) {
                    EventData eventData =
                        await spongeService.createEventData(event);
                    _logger.fine(
                        'Subscription ${subscription.id ?? ''} - received event: ${event.id}, ${event.name}, ${event.label}, ${event.attributes}');
                    await spongeService.addEvent(eventData);

                    await showEventNotification(eventData);
                  }
                } catch (e) {
                  _logger.severe(
                      'Subscription ${subscription.id ?? ''} - event processing error: $e');
                }
              },
              onError: (e) {
                _logger.severe(
                    'Subscription ${subscription.id ?? ''} - error: $e');
              },
              onDone: () {
                _logger.info('Subscription ${subscription.id ?? ''} - done');
              },
            );
          }
        } catch (e) {
          _logger.severe('Subscribe error: $e');
        }
      } finally {
        // Start the watchdog.
        _subscriptionWatchdog = Timer.periodic(
            Duration(seconds: settings.subscriptionWatchdogInterval),
            (timer) async {
          if (activeConnection.subscribe && !spongeService.isSubscribed) {
            // Cancel the current watchdog.
            timer.cancel();

            _logger.info('Resubscribing...');
            await subscribe(spongeService);
          }
        });
      }
    } else {
      unawaited(spongeService
          .unsubscribe()
          .catchError((e) => _logger.severe('Unsubscribe error: $e')));
    }
  }

  Future<void> showEventNotification(EventData eventData) async {}
}

class FlutterSpongeService extends SpongeService<FlutterActionData> {
  FlutterSpongeService(
    SpongeConnection connection,
    TypeConverter typeConverter,
    this.typeGuiProvider, {
    Map<String, ActionIntentHandler> actionIntentHandlers,
  }) : super(connection,
            typeConverter: typeConverter,
            actionIntentHandlers: actionIntentHandlers);

  final TypeGuiProvider typeGuiProvider;

  @override
  FlutterActionData createActionData(ActionMeta actionMeta) =>
      FlutterActionData(actionMeta, typeGuiProvider);
}

class FlutterApplicationSettings extends ApplicationSettings {
  FlutterApplicationSettings(this._prefs);

  static const String _PREF_PREFIX = 'settings.';

  static const String PREF_ACTION_LIST_TABS = '$_PREF_PREFIX.tabsInActionList';

  static const String PREF_ACTION_CALL_ON_TAP = '$_PREF_PREFIX.actionCallOnTap';

  static const String PREF_ACTION_SWIPE_TO_CLOSE =
      '$_PREF_PREFIX.actionSwipeToClose';

  static const String PREF_USE_INTERNAL_VIEWERS =
      '$_PREF_PREFIX.useInternalViewers';

  static const String PREF_TEXT_VIEWER_WIDTH = '$_PREF_PREFIX.textViewerWidth';

  static const String PREF_ARGUMENT_LIST_ELEMENT_TAP_BEHAVIOR =
      '$_PREF_PREFIX.argumentListElementTapBehavior';

  static const String PREF_ACTION_ICONS_VIEW = '$_PREF_PREFIX.actionIconsView';

  static const String PREF_ACTIONS_ORDER = '$_PREF_PREFIX.actionsOrder';

  // TODO Remove drawAntiAliasing.
  //static const String PREF_DRAW_ANTI_ALIASING = '$PREF_PREFIX.drawAntiAliasing';

  static const String PREF_AUTO_USE_AUTH_TOKEN =
      '$_PREF_PREFIX.autoUseAuthToken';

  static const String PREF_MAX_EVENT_COUNT = '$_PREF_PREFIX.maxEventCount';

  static const String PREF_SUBSCRIPTION_WATCHDOG_INTERVAL =
      '$_PREF_PREFIX.subscriptionWatchdogInterval';

  static const String PREF_USE_SCROLLABLE_INDEXED_LIST =
      '$_PREF_PREFIX.useScrollableIndexedList';

  static const String PREF_FILTER_CONNECTIONS_BY_NETWORK =
      '$_PREF_PREFIX.filterConnectionsByNetwork';

  static const String PREF_DRAWING_STROKE_UPDATE_DELTA_THRESHOLD_RATIO =
      '$_PREF_PREFIX.drawingStrokeUpdateDeltaThresholdRatio';

  static const String PREF_SERVICE_DISCOVERY_TIMEOUT =
      '$_PREF_PREFIX.serviceDiscoveryTimeout';

  static const int MAX_SUBSCRIPTION_WATCHDOG_INTERVAL = 360;

  static const int MAX_SERVICE_DISCOVERY_TIMEOUT = 60;

  final SharedPreferences _prefs;

  Brightness get defaultThemeBrightness => Brightness.dark;

  bool get tabsInActionList => _prefs.getBool(PREF_ACTION_LIST_TABS) ?? true;

  Future<bool> setTabsInActionList(bool value) async =>
      await _prefs.setBool(PREF_ACTION_LIST_TABS, value);

  bool get actionCallOnTap => _prefs.getBool(PREF_ACTION_CALL_ON_TAP) ?? true;

  Future<bool> setActionCallOnTap(bool value) async =>
      await _prefs.setBool(PREF_ACTION_CALL_ON_TAP, value);

  bool get actionSwipeToClose =>
      _prefs.getBool(PREF_ACTION_SWIPE_TO_CLOSE) ?? true;

  Future<bool> setActionSwipeToClose(bool value) async =>
      await _prefs.setBool(PREF_ACTION_SWIPE_TO_CLOSE, value);

  bool get useInternalViewers =>
      _prefs.getBool(PREF_USE_INTERNAL_VIEWERS) ?? false;

  Future<bool> setUseInternalViewers(bool value) async =>
      await _prefs.setBool(PREF_USE_INTERNAL_VIEWERS, value);

  int get textViewerWidth => _prefs.getInt(PREF_TEXT_VIEWER_WIDTH);

  Future<bool> setTextViewerWidth(int value) async =>
      await _prefs.setInt(PREF_TEXT_VIEWER_WIDTH, value);

  String get argumentListElementTapBehavior =>
      _prefs.getString(PREF_ARGUMENT_LIST_ELEMENT_TAP_BEHAVIOR) ??
      argumentListElementTapBehaviorValueSet[0].value;

  Future<bool> setArgumentListElementTapBehavior(String value) async =>
      await _prefs.setString(PREF_ARGUMENT_LIST_ELEMENT_TAP_BEHAVIOR, value);

  List<AnnotatedValue> get argumentListElementTapBehaviorValueSet => [
        AnnotatedValue('read', valueLabel: 'View'),
        AnnotatedValue('update', valueLabel: 'Modify')
      ];

  @override
  ActionIconsView get actionIconsView =>
      ActionIconsView.values.firstWhere(
          (e) => e.toString() == _prefs.getString(PREF_ACTION_ICONS_VIEW),
          orElse: () => null) ??
      ActionIconsView.custom;

  Future<bool> setActionIconsView(ActionIconsView value) async =>
      await _prefs.setString(PREF_ACTION_ICONS_VIEW, value.toString());

  List<AnnotatedValue> get actionIconsViewValueSet => [
        AnnotatedValue(ActionIconsView.custom, valueLabel: 'Custom icons'),
        AnnotatedValue(ActionIconsView.internal, valueLabel: 'Internal icons'),
        AnnotatedValue(ActionIconsView.none, valueLabel: 'No icons'),
      ];

  @override
  ActionsOrder get actionsOrder =>
      ActionsOrder.values.firstWhere(
          (e) => e.toString() == _prefs.getString(PREF_ACTIONS_ORDER),
          orElse: () => null) ??
      ActionsOrder.defaultOrder;

  Future<bool> setActionsOrder(ActionsOrder value) async =>
      await _prefs.setString(PREF_ACTIONS_ORDER, value.toString());

  List<AnnotatedValue> get actionsOrderValueSet => [
        AnnotatedValue(ActionsOrder.defaultOrder, valueLabel: 'Default'),
        AnnotatedValue(ActionsOrder.alphabetical, valueLabel: 'Alphabetical'),
      ];

  // TODO Remove drawAntiAliasing.
  bool get drawAntiAliasing =>
      true; //_prefs.getBool(PREF_DRAW_ANTI_ALIASING) ?? false;

  // Future<bool> setDrawAntiAliasing(bool value) async =>
  //     await _prefs.setBool(PREF_DRAW_ANTI_ALIASING, value);

  bool get autoUseAuthToken => _prefs.getBool(PREF_AUTO_USE_AUTH_TOKEN) ?? true;

  Future<bool> setAutoUseAuthToken(bool value) async =>
      await _prefs.setBool(PREF_AUTO_USE_AUTH_TOKEN, value);

  int get maxEventCount => _prefs.getInt(PREF_MAX_EVENT_COUNT) ?? 100;

  Future<bool> setMaxEventCount(int value) async =>
      await _prefs.setInt(PREF_MAX_EVENT_COUNT, value);

  int get subscriptionWatchdogInterval =>
      _prefs.getInt(PREF_SUBSCRIPTION_WATCHDOG_INTERVAL) ?? 5;

  Future<bool> setSubscriptionWatchdogInterval(int value) async {
    Validate.isTrue(value >= 0 && value <= MAX_SUBSCRIPTION_WATCHDOG_INTERVAL,
        'The subscription watchdog interval must be a value between 0 and $MAX_SUBSCRIPTION_WATCHDOG_INTERVAL');

    return await _prefs.setInt(PREF_SUBSCRIPTION_WATCHDOG_INTERVAL, value);
  }

  bool get useScrollableIndexedList =>
      _prefs.getBool(PREF_USE_SCROLLABLE_INDEXED_LIST) ?? false;

  Future<bool> setUseScrollableIndexedList(bool value) async =>
      await _prefs.setBool(PREF_USE_SCROLLABLE_INDEXED_LIST, value);

  bool get filterConnectionsByNetwork =>
      _prefs.getBool(PREF_FILTER_CONNECTIONS_BY_NETWORK) ?? false;

  Future<bool> setFilterConnectionsByNetwork(bool value) async =>
      await _prefs.setBool(PREF_FILTER_CONNECTIONS_BY_NETWORK, value);

  double get drawingStrokeUpdateDeltaThresholdRatio =>
      _prefs.getDouble(PREF_DRAWING_STROKE_UPDATE_DELTA_THRESHOLD_RATIO) ??
      PainterController.DEFAULT_STROKE_UPDATE_DELTA_THRESHOLD_RATIO;

  Future<bool> setDrawingStrokeUpdateDeltaThresholdRatio(double value) async =>
      await _prefs.setDouble(
          PREF_DRAWING_STROKE_UPDATE_DELTA_THRESHOLD_RATIO, value);

  int get serviceDiscoveryTimeout =>
      _prefs.getInt(PREF_SERVICE_DISCOVERY_TIMEOUT) ?? 5;

  Future<bool> setServiceDiscoveryTimeout(int value) async {
    Validate.isTrue(value >= 0 && value <= MAX_SERVICE_DISCOVERY_TIMEOUT,
        'The service discovery timeout must be a value between 0 and $MAX_SERVICE_DISCOVERY_TIMEOUT');

    return await _prefs.setInt(PREF_SERVICE_DISCOVERY_TIMEOUT, value);
  }

  @override
  Future<void> clear() async {
    for (var key in _prefs
        .getKeys()
        .where((key) => key.startsWith(_PREF_PREFIX))
        .toList()) {
      await _prefs.remove(key);
    }
  }
}

class EventNotificationState with ChangeNotifier {
  RemoteEvent _lastEvent;

  RemoteEvent get lastEvent => _lastEvent;

  set lastEvent(RemoteEvent value) {
    _lastEvent = value;
    notifyListeners();
  }
}
