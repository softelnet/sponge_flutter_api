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

import 'package:flutter/material.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/gui_constants.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_settings.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/util/utils.dart';

class SettingsPage extends StatefulWidget {
  SettingsPage({Key key}) : super(key: key);

  @override
  createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _textViewerWidthSliderValue;
  static const MAX_TEXT_VIEWER_WIDTH_SLIDER_VALUE = 10;
  int _maxEventCountSliderValue;
  static const MAX_MAX_EVENT_COUNT_SLIDER_VALUE = 10;
  static const MAX_EVENT_COUNT_RATIO = 10;

  TextEditingController _subscriptionWatchdogIntervalController;
  TextEditingController _serviceDiscoveryTimeoutController;

  FlutterApplicationSettings get settings =>
      ApplicationProvider.of(context).service.settings;

  @override
  Widget build(BuildContext context) {
    _textViewerWidthSliderValue ??=
        ApplicationProvider.of(context).service.settings.textViewerWidth ?? 0;
    if (_textViewerWidthSliderValue > MAX_TEXT_VIEWER_WIDTH_SLIDER_VALUE) {
      _textViewerWidthSliderValue = MAX_TEXT_VIEWER_WIDTH_SLIDER_VALUE;
    }

    _maxEventCountSliderValue ??=
        (ApplicationProvider.of(context).service.settings.maxEventCount ?? 0) ~/
            MAX_EVENT_COUNT_RATIO;
    if (_maxEventCountSliderValue > MAX_MAX_EVENT_COUNT_SLIDER_VALUE) {
      _maxEventCountSliderValue = MAX_MAX_EVENT_COUNT_SLIDER_VALUE;
    }

    _subscriptionWatchdogIntervalController ??= TextEditingController(
      text: '${settings.subscriptionWatchdogInterval}',
    );

    _serviceDiscoveryTimeoutController ??= TextEditingController(
      text: '${settings.serviceDiscoveryTimeout}',
    );

    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Settings'),
          actions: [
            Builder(
              builder: (BuildContext context) => _buildMenu(context),
            )
          ],
        ),
        body: SafeArea(
          child: Builder(
            builder: (BuildContext context) => Container(
              margin: const EdgeInsets.only(top: 20.0, bottom: 20.0),
              child: ListView(
                key: PageStorageKey('settings-groups'),
                children: <Widget>[
                  _buildGroup(
                    name: 'theme',
                    title: 'Theme',
                    initiallyExpanded: true,
                    children: [
                      ListTile(
                        title: Text('Dark theme'),
                        trailing: Switch(
                          value: settings.isDarkMode,
                          onChanged: (value) => _toggleTheme(context),
                        ),
                        onTap: () => _toggleTheme(context),
                      )
                    ],
                  ),
                  _buildGroup(
                    name: 'actions',
                    title: 'Actions',
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        title: Text(
                            'Show tabs for action categories and knowledge bases'),
                        trailing: Switch(
                            value: settings.tabsInActionList,
                            onChanged: (value) => _toggleTabsInActionList()),
                        onTap: () => _toggleTabsInActionList(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title:
                            Text('Action call simplified by a tap on an item'),
                        trailing: Switch(
                            value: settings.actionCallOnTap,
                            onChanged: (value) => _toggleActionCallOnTap()),
                        onTap: () => _toggleActionCallOnTap(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title:
                            Text('Action argument list element tap behavior'),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton(
                            value: settings.argumentListElementTapBehavior,
                            items: settings
                                .argumentListElementTapBehaviorValueSet
                                .map((annotatedValue) => DropdownMenuItem(
                                      value: annotatedValue.value,
                                      child: Text(annotatedValue.valueLabel),
                                    ))
                                .toList(),
                            onChanged: (value) async {
                              setState(() {});
                              await settings
                                  .setArgumentListElementTapBehavior(value);
                            },
                            isDense: true,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: Text('Action icons view'),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton(
                            value: settings.actionIconsView,
                            items: settings.actionIconsViewValueSet
                                .map((annotatedValue) => DropdownMenuItem(
                                      value: annotatedValue.value,
                                      child: Text(annotatedValue.valueLabel),
                                    ))
                                .toList(),
                            onChanged: (value) async {
                              setState(() {});
                              await settings.setActionIconsView(value);
                            },
                            isDense: true,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: Text('Actions order'),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton(
                            value: settings.actionsOrder,
                            items: settings.actionsOrderValueSet
                                .map((annotatedValue) => DropdownMenuItem(
                                      value: annotatedValue.value,
                                      child: Text(annotatedValue.valueLabel),
                                    ))
                                .toList(),
                            onChanged: (value) async {
                              setState(() {});
                              await settings.setActionsOrder(value);
                            },
                            isDense: true,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      ListTile(
                        title:
                            Text('Swipe to close action (from left to right)'),
                        trailing: Switch(
                            value: settings.actionSwipeToClose,
                            onChanged: (value) => _toggleActionSwipeToClose()),
                        onTap: () => _toggleActionSwipeToClose(),
                      ),
                    ],
                  ),
                  _buildGroup(
                    name: 'events',
                    title: 'Events',
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        title: Text('Number of stored events ' +
                            (_maxEventCountSliderValue > 0
                                ? '(${_maxEventCountSliderValue * MAX_EVENT_COUNT_RATIO})'
                                : '(infinite)')),
                        subtitle: Slider(
                          activeColor: Theme.of(context).accentColor,
                          label: '$_maxEventCountSliderValue',
                          min: 0,
                          max: MAX_MAX_EVENT_COUNT_SLIDER_VALUE.roundToDouble(),
                          value:
                              _maxEventCountSliderValue?.roundToDouble() ?? 0,
                          onChanged: (value) async {
                            setState(() =>
                                _maxEventCountSliderValue = value.toInt());
                            await settings.setMaxEventCount(
                                value.toInt() * MAX_EVENT_COUNT_RATIO);
                          },
                        ),
                      ),
                      Divider(),
                      ListTile(
                        title:
                            Text('Subscription watchdog interval (in seconds)'),
                        subtitle: TextField(
                          // The key is required here, see https://github.com/flutter/flutter/issues/36539.
                          key: PageStorageKey(
                              'setting-subscriptionWatchdogInterval'),
                          keyboardType: TextInputType.number,
                          controller: _subscriptionWatchdogIntervalController,
                          onSubmitted: (value) async {
                            try {
                              await settings.setSubscriptionWatchdogInterval(
                                  int.parse(value));
                            } catch (e) {
                              await handleError(context, e);
                              _subscriptionWatchdogIntervalController.text =
                                  '${settings.subscriptionWatchdogInterval}';
                            }
                          },
                          decoration: InputDecoration(
                              border: const OutlineInputBorder()),
                        ),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Show new event notification'),
                        trailing: Switch(
                            value: settings.showNewEventNotification,
                            onChanged: (value) =>
                                _toggleShowNewEventNotification()),
                        onTap: () => _toggleShowNewEventNotification(),
                      ),
                    ],
                  ),
                  _buildGroup(
                    name: 'dataTypes',
                    title: 'Data types',
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        title: Text('Use internal viewers if possible'),
                        trailing: Switch(
                            value: settings.useInternalViewers,
                            onChanged: (value) => _toggleUseInternalViewers()),
                        onTap: () => _toggleUseInternalViewers(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: Text('Text viewer width in pixels ' +
                            (_textViewerWidthSliderValue > 0
                                ? '(${_textViewerWidthSliderValue * GuiConstants.TEXT_VIEWER_WIDTH_SCALE})'
                                : '(default)')),
                        subtitle: Slider(
                          activeColor: Theme.of(context).accentColor,
                          label: '$_textViewerWidthSliderValue',
                          min: 0,
                          max: MAX_TEXT_VIEWER_WIDTH_SLIDER_VALUE
                              .roundToDouble(),
                          value:
                              _textViewerWidthSliderValue?.roundToDouble() ?? 0,
                          onChanged: (value) async {
                            setState(() =>
                                _textViewerWidthSliderValue = value.toInt());
                            await settings.setTextViewerWidth(value.toInt());
                          },
                        ),
                      ),
                      _buildDivider(),
                      ListTile(
                        title:
                            Text('Use scrollable indexed list (experimental)'),
                        trailing: Switch(
                            value: settings.useScrollableIndexedList,
                            onChanged: (value) =>
                                _toggleUseScrollableIndexedList()),
                        onTap: () => _toggleUseScrollableIndexedList(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: Text(
                            'Drawing stroke update delta threshold ratio (${settings.drawingStrokeUpdateDeltaThresholdRatio})'),
                        subtitle: Slider(
                          activeColor: Theme.of(context).accentColor,
                          label:
                              '${settings.drawingStrokeUpdateDeltaThresholdRatio}',
                          value:
                              settings.drawingStrokeUpdateDeltaThresholdRatio,
                          divisions: 20,
                          onChanged: (value) async {
                            await settings
                                .setDrawingStrokeUpdateDeltaThresholdRatio(
                                    value);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  _buildGroup(
                    name: 'map',
                    title: 'Map',
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        title: Text('Cluster data markers'),
                        trailing: Switch(
                            value: settings.mapEnableClusterMarkers,
                            onChanged: (value) =>
                                _toggleMapEnableClusterMarkers()),
                        onTap: () => _toggleMapEnableClusterMarkers(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: Text('Show marker badges'),
                        trailing: Switch(
                            value: settings.mapEnableMarkerBadges,
                            onChanged: (value) =>
                                _toggleMapEnableMarkerBadges()),
                        onTap: () => _toggleMapEnableMarkerBadges(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: Text('Show current location (experimental)'),
                        trailing: Switch(
                            value: settings.mapEnableCurrentLocation,
                            onChanged: (value) =>
                                _toggleMapEnableCurrentLocation()),
                        onTap: () => _toggleMapEnableCurrentLocation(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: Text('Follow current location'),
                        trailing: Switch(
                            value: settings.mapFollowCurrentLocation,
                            onChanged: (value) =>
                                _toggleMapFollowCurrentLocation()),
                        onTap: () => _toggleMapFollowCurrentLocation(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: Text('Full screen'),
                        trailing: Switch(
                            value: settings.mapFullScreen,
                            onChanged: (value) => _toggleMapFullScreen()),
                        onTap: () => _toggleMapFullScreen(),
                      ),
                    ],
                  ),
                  _buildGroup(
                    name: 'connections',
                    title: 'Connections',
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        title: Text('Use authentication token'),
                        trailing: Switch(
                            value: settings.autoUseAuthToken,
                            onChanged: (value) => _toggleAutoUseAuthToken()),
                        onTap: () => _toggleAutoUseAuthToken(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: Text('Service discovery timeot (in seconds)'),
                        subtitle: TextField(
                          // The key is required here, see https://github.com/flutter/flutter/issues/36539.
                          key:
                              PageStorageKey('setting-serviceDiscoveryTimeout'),
                          keyboardType: TextInputType.number,
                          controller: _serviceDiscoveryTimeoutController,
                          onSubmitted: (value) async {
                            try {
                              await settings
                                  .setServiceDiscoveryTimeout(int.parse(value));
                            } catch (e) {
                              await handleError(context, e);
                              _serviceDiscoveryTimeoutController.text =
                                  '${settings.serviceDiscoveryTimeout}';
                            }
                          },
                          decoration: InputDecoration(
                              border: const OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      onWillPop: _submit,
    );
  }

  Widget _buildGroup({
    @required String name,
    @required String title,
    @required List<Widget> children,
    bool initiallyExpanded = true,
  }) {
    return ExpansionTile(
      key: PageStorageKey('setting-group-$name'),
      title: Text(title),
      initiallyExpanded: initiallyExpanded,
      children: children,
    );
  }

  Widget _buildDivider() {
    return Divider(
      indent: 10,
      endIndent: 10,
    );
  }

  Widget _buildMenu(BuildContext context) => PopupMenuButton<String>(
        key: Key('settings-menu'),
        onSelected: (value) {
          if (value == 'reset') {
            _resetToDefaults(context);
          }
        },
        itemBuilder: (BuildContext context) => [
          PopupMenuItem<String>(
            key: Key('settings-menu-reset'),
            value: 'reset',
            child: IconTextPopupMenuItemWidget(
              icon: Icons.restore,
              text: 'Reset to defaults',
            ),
          ),
        ],
        padding: EdgeInsets.zero,
      );

  Future<void> _toggleTabsInActionList() async {
    await settings.setTabsInActionList(!settings.tabsInActionList);
    setState(() {});
  }

  Future<void> _toggleActionCallOnTap() async {
    await settings.setActionCallOnTap(!settings.actionCallOnTap);
    setState(() {});
  }

  Future<void> _toggleActionSwipeToClose() async {
    await settings.setActionSwipeToClose(!settings.actionSwipeToClose);
    setState(() {});
  }

  Future<void> _toggleUseInternalViewers() async {
    await settings.setUseInternalViewers(!settings.useInternalViewers);
    setState(() {});
  }

  Future<void> _toggleUseScrollableIndexedList() async {
    await settings
        .setUseScrollableIndexedList(!settings.useScrollableIndexedList);
    setState(() {});
  }

  Future<void> _toggleAutoUseAuthToken() async {
    await settings.setAutoUseAuthToken(!settings.autoUseAuthToken);
    setState(() {});
  }

  Future<void> _toggleShowNewEventNotification() async {
    await settings
        .setShowNewEventNotification(!settings.showNewEventNotification);
    setState(() {});
  }

  Future<void> _toggleMapEnableClusterMarkers() async {
    await settings
        .setMapEnableClusterMarkers(!settings.mapEnableClusterMarkers);
    setState(() {});
  }

  Future<void> _toggleMapEnableMarkerBadges() async {
    await settings.setMapEnableMarkerBadges(!settings.mapEnableMarkerBadges);
    setState(() {});
  }

  Future<void> _toggleMapEnableCurrentLocation() async {
    await settings
        .setMapEnableCurrentLocation(!settings.mapEnableCurrentLocation);
    setState(() {});
  }

  Future<void> _toggleMapFollowCurrentLocation() async {
    await settings
        .setMapFollowCurrentLocation(!settings.mapFollowCurrentLocation);
    setState(() {});
  }

  Future<void> _toggleMapFullScreen() async {
    await settings.setMapFullScreen(!settings.mapFullScreen);
    setState(() {});
  }

  Future<void> _toggleTheme(BuildContext context) async {
    await settings.setIsDarkMode(!settings.isDarkMode);
  }

  Future<void> _resetToDefaults(BuildContext context) async {
    try {
      bool cleared = await _clearSettings(context);
      if (cleared) {
        var backgroudColor = getPrimaryColor(context);
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text(
            'Settings have been reset to the default values',
            style: TextStyle(color: getContrastColor(backgroudColor)),
          ),
          backgroundColor: backgroudColor,
        ));
      }
    } catch (e) {
      await handleError(context, e);
    }
  }

  Future<bool> _clearSettings(BuildContext context) async {
    if (!await showConfirmationDialog(context,
        'Do you want to reset the current settings to the default values?')) {
      return false;
    }

    await ApplicationProvider.of(context).service.clearSettings();

    setState(() {});

    return true;
  }

  Future<bool> _submit() async {
    ApplicationProvider.of(context).service.spongeService?.maxEventCount =
        _maxEventCountSliderValue * MAX_EVENT_COUNT_RATIO;

    return true;
  }
}
