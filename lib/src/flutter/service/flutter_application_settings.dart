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

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/external/painter.dart';

class FlutterApplicationSettings extends ApplicationSettings {
  FlutterApplicationSettings(this._prefs, this._stateNotifier);

  static const String _PREF_PREFIX = 'settings.';

  static const String PREF_IS_DARK_MODE = '$_PREF_PREFIX.isDarkMode';

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

  static const String PREF_SHOW_NEW_EVENT_NOTIFICATION =
      '$_PREF_PREFIX.showNewEventNotification';

  static const String PREF_MAP_ENABLE_CLUSTER_MARKERS =
      '$_PREF_PREFIX.mapEnableClusterMarkers';
  static const String PREF_MAP_ENABLE_MARKER_BADGES =
      '$_PREF_PREFIX.mapEnableMarkerBadges';
  static const String PREF_MAP_ENABLE_CURRENT_LOCATION =
      '$_PREF_PREFIX.mapEnableCurrentLocation';
  static const String PREF_MAP_FOLLOW_CURRENT_LOCATION =
      '$_PREF_PREFIX.mapFollowCurrentLocation';
  static const String PREF_MAP_FULL_SCREEN = '$_PREF_PREFIX.mapFullScreen';

  static const int MAX_SUBSCRIPTION_WATCHDOG_INTERVAL = 360;

  static const int MAX_SERVICE_DISCOVERY_TIMEOUT = 60;

  final SharedPreferences _prefs;

  final ApplicationStateNotifier _stateNotifier;

  bool get isDarkMode => _prefs.getBool(PREF_IS_DARK_MODE) ?? true;

  Future<bool> setIsDarkMode(bool value) async {
    var result = await _prefs.setBool(PREF_IS_DARK_MODE, value);

    _stateNotifier.notify();

    return result;
  }

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

  bool get showNewEventNotification =>
      _prefs.getBool(PREF_SHOW_NEW_EVENT_NOTIFICATION) ?? true;

  Future<bool> setShowNewEventNotification(bool value) async =>
      await _prefs.setBool(PREF_SHOW_NEW_EVENT_NOTIFICATION, value);

  bool get mapEnableClusterMarkers =>
      _prefs.getBool(PREF_MAP_ENABLE_CLUSTER_MARKERS) ?? true;

  Future<bool> setMapEnableClusterMarkers(bool value) async =>
      await _prefs.setBool(PREF_MAP_ENABLE_CLUSTER_MARKERS, value);

  bool get mapEnableMarkerBadges =>
      _prefs.getBool(PREF_MAP_ENABLE_MARKER_BADGES) ?? false;

  Future<bool> setMapEnableMarkerBadges(bool value) async =>
      await _prefs.setBool(PREF_MAP_ENABLE_MARKER_BADGES, value);

  bool get mapEnableCurrentLocation =>
      _prefs.getBool(PREF_MAP_ENABLE_CURRENT_LOCATION) ?? false;

  Future<bool> setMapEnableCurrentLocation(bool value) async =>
      await _prefs.setBool(PREF_MAP_ENABLE_CURRENT_LOCATION, value);

  bool get mapFollowCurrentLocation =>
      _prefs.getBool(PREF_MAP_FOLLOW_CURRENT_LOCATION) ?? false;

  Future<bool> setMapFollowCurrentLocation(bool value) async =>
      await _prefs.setBool(PREF_MAP_FOLLOW_CURRENT_LOCATION, value);

  bool get mapFullScreen => _prefs.getBool(PREF_MAP_FULL_SCREEN) ?? false;

  Future<bool> setMapFullScreen(bool value) async =>
      await _prefs.setBool(PREF_MAP_FULL_SCREEN, value);

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
