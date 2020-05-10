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

import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';
import 'package:sponge_flutter_api/src/flutter/gui_constants.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_settings.dart';

class SettingsViewModel extends BaseViewModel {}

abstract class SettingsView extends BaseView {
  void refresh();
}

class SettingsPresenter extends BasePresenter<SettingsViewModel, SettingsView> {
  SettingsPresenter(ApplicationService service, SettingsView view)
      : super(service, SettingsViewModel(), view) {
    _init();
  }

  static const MAX_TEXT_VIEWER_WIDTH_SLIDER_VALUE = 10;
  static const MAX_MAX_EVENT_COUNT_SLIDER_VALUE = 10;
  static const MAX_EVENT_COUNT_RATIO = 10;

  int _textViewerWidthSliderValue;
  int _maxEventCountSliderValue;

  @override
  FlutterApplicationService get service => super.service;

  FlutterApplicationSettings get settings => service.settings;

  void _init() {
    _textViewerWidthSliderValue ??= settings.textViewerWidth ?? 0;
    if (_textViewerWidthSliderValue > MAX_TEXT_VIEWER_WIDTH_SLIDER_VALUE) {
      _textViewerWidthSliderValue = MAX_TEXT_VIEWER_WIDTH_SLIDER_VALUE;
    }

    _maxEventCountSliderValue ??=
        (settings.maxEventCount ?? 0) ~/ MAX_EVENT_COUNT_RATIO;
    if (_maxEventCountSliderValue > MAX_MAX_EVENT_COUNT_SLIDER_VALUE) {
      _maxEventCountSliderValue = MAX_MAX_EVENT_COUNT_SLIDER_VALUE;
    }
  }

  String get maxEventCountTitle =>
      'Number of stored events ' +
      (_maxEventCountSliderValue > 0
          ? '(${_maxEventCountSliderValue * MAX_EVENT_COUNT_RATIO})'
          : '(infinite)');

  String get maxEventCountValueLabel => '$_maxEventCountSliderValue';

  double get maxEventCountMaxValue =>
      MAX_MAX_EVENT_COUNT_SLIDER_VALUE.roundToDouble();

  double get maxEventCountValue =>
      _maxEventCountSliderValue?.roundToDouble() ?? 0;

  Future<void> onMaxEventCountChange(double value) async {
    _maxEventCountSliderValue = value.toInt();
    await settings.setMaxEventCount(value.toInt() * MAX_EVENT_COUNT_RATIO);

    view.refresh();
  }

  String get useInternalViewersTitle =>
      'Text viewer width in pixels ' +
      (_textViewerWidthSliderValue > 0
          ? '(${_textViewerWidthSliderValue * GuiConstants.TEXT_VIEWER_WIDTH_SCALE})'
          : '(default)');

  String get useInternalViewersValueLabel => '$_textViewerWidthSliderValue';

  double get useInternalViewersMaxValue =>
      MAX_TEXT_VIEWER_WIDTH_SLIDER_VALUE.roundToDouble();

  double get useInternalViewersValue =>
      _textViewerWidthSliderValue?.roundToDouble() ?? 0;

  Future<void> onUseInternalViewersChange(double value) async {
    _textViewerWidthSliderValue = value.toInt();
    await settings.setTextViewerWidth(value.toInt());

    view.refresh();
  }

  Future<void> toggleTabsInActionList() async {
    await settings.setTabsInActionList(!settings.tabsInActionList);

    view.refresh();
  }

  Future<void> toggleActionCallOnTap() async {
    await settings.setActionCallOnTap(!settings.actionCallOnTap);

    view.refresh();
  }

  Future<void> toggleActionSwipeToClose() async {
    await settings.setActionSwipeToClose(!settings.actionSwipeToClose);

    view.refresh();
  }

  Future<void> toggleUseInternalViewers() async {
    await settings.setUseInternalViewers(!settings.useInternalViewers);

    view.refresh();
  }

  Future<void> toggleUseScrollableIndexedList() async {
    await settings
        .setUseScrollableIndexedList(!settings.useScrollableIndexedList);

    view.refresh();
  }

  Future<void> toggleAutoUseAuthToken() async {
    await settings.setAutoUseAuthToken(!settings.autoUseAuthToken);

    view.refresh();
  }

  Future<void> toggleShowNewEventNotification() async {
    await settings
        .setShowNewEventNotification(!settings.showNewEventNotification);

    view.refresh();
  }

  Future<void> toggleMapEnableClusterMarkers() async {
    await settings
        .setMapEnableClusterMarkers(!settings.mapEnableClusterMarkers);

    view.refresh();
  }

  Future<void> toggleMapEnableMarkerBadges() async {
    await settings.setMapEnableMarkerBadges(!settings.mapEnableMarkerBadges);

    view.refresh();
  }

  Future<void> toggleMapEnableCurrentLocation() async {
    await settings
        .setMapEnableCurrentLocation(!settings.mapEnableCurrentLocation);

    view.refresh();
  }

  Future<void> toggleMapFollowCurrentLocation() async {
    await settings
        .setMapFollowCurrentLocation(!settings.mapFollowCurrentLocation);

    view.refresh();
  }

  Future<void> toggleMapFullScreen() async {
    await settings.setMapFullScreen(!settings.mapFullScreen);

    view.refresh();
  }

  Future<void> toggleTheme() async {
    await settings.setIsDarkMode(!settings.isDarkMode);
  }

  Future<void> onArgumentListElementTapBehaviorChange(String value) async {
    await settings.setArgumentListElementTapBehavior(value);

    view.refresh();
  }

  Future<void> onActionIconsViewChange(dynamic value) async {
    await settings.setActionIconsView(value);

    view.refresh();
  }

  Future<void> onActionsOrderChange(dynamic value) async {
    await settings.setActionsOrder(value);

    view.refresh();
  }

  String get drawingStrokeUpdateDeltaThresholdRatioTitle =>
      'Drawing stroke update delta threshold ratio (${settings.drawingStrokeUpdateDeltaThresholdRatio})';

  String get drawingStrokeUpdateDeltaThresholdRatioValueLabel =>
      '${settings.drawingStrokeUpdateDeltaThresholdRatio}';

  int get drawingStrokeUpdateDeltaThresholdRatioDivisions => 20;

  Future<void> onDrawingStrokeUpdateDeltaThresholdRatioChange(
      double value) async {
    await settings.setDrawingStrokeUpdateDeltaThresholdRatio(value);

    view.refresh();
  }

  Future<void> submit() async {
    service.spongeService?.maxEventCount =
        _maxEventCountSliderValue * MAX_EVENT_COUNT_RATIO;
  }

  Future<void> clearSettings() async {
    await service.clearSettings();

    view.refresh();

    return true;
  }
}
