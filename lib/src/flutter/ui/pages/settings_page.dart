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
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_settings.dart';
import 'package:sponge_flutter_api/src/flutter/ui/mvp/pages/settings_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/widgets.dart';

class SettingsPage extends StatefulWidget {
  SettingsPage({Key key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> implements SettingsView {
  SettingsPresenter _presenter;

  TextEditingController _subscriptionWatchdogIntervalController;
  TextEditingController _serviceDiscoveryTimeoutController;

  FlutterApplicationSettings get settings => _presenter?.settings;

  @override
  Widget build(BuildContext context) {
    _presenter ??=
        SettingsPresenter(ApplicationProvider.of(context).service, this);

    _subscriptionWatchdogIntervalController ??= TextEditingController(
      text: '${settings.subscriptionWatchdogInterval}',
    );

    _serviceDiscoveryTimeoutController ??= TextEditingController(
      text: '${settings.serviceDiscoveryTimeout}',
    );

    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
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
                        title: const Text('Dark theme'),
                        trailing: Switch(
                          value: settings.isDarkMode,
                          onChanged: (value) => _presenter.toggleTheme(),
                        ),
                        onTap: () => _presenter.toggleTheme(),
                      )
                    ],
                  ),
                  _buildGroup(
                    name: 'actions',
                    title: 'Actions',
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        title: const Text(
                            'Show tabs for action categories and knowledge bases'),
                        trailing: Switch(
                            value: settings.tabsInActionList,
                            onChanged: (value) =>
                                _presenter.toggleTabsInActionList()),
                        onTap: () => _presenter.toggleTabsInActionList(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: const Text(
                            'Action call simplified by a tap on an item'),
                        trailing: Switch(
                            value: settings.actionCallOnTap,
                            onChanged: (value) =>
                                _presenter.toggleActionCallOnTap()),
                        onTap: () => _presenter.toggleActionCallOnTap(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: const Text(
                            'Action argument list element tap behavior'),
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
                            onChanged: (value) async => _presenter
                                .onArgumentListElementTapBehaviorChange(value),
                            isDense: true,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: const Text('Action icons view'),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton(
                            value: settings.actionIconsView,
                            items: settings.actionIconsViewValueSet
                                .map((annotatedValue) => DropdownMenuItem(
                                      value: annotatedValue.value,
                                      child: Text(annotatedValue.valueLabel),
                                    ))
                                .toList(),
                            onChanged: (value) async =>
                                _presenter.onActionIconsViewChange(value),
                            isDense: true,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: const Text('Actions order'),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton(
                            value: settings.actionsOrder,
                            items: settings.actionsOrderValueSet
                                .map((annotatedValue) => DropdownMenuItem(
                                      value: annotatedValue.value,
                                      child: Text(annotatedValue.valueLabel),
                                    ))
                                .toList(),
                            onChanged: (value) async =>
                                _presenter.onActionsOrderChange(value),
                            isDense: true,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: const Text(
                            'Swipe to close action (from left to right)'),
                        trailing: Switch(
                            value: settings.actionSwipeToClose,
                            onChanged: (value) =>
                                _presenter.toggleActionSwipeToClose()),
                        onTap: () => _presenter.toggleActionSwipeToClose(),
                      ),
                    ],
                  ),
                  _buildGroup(
                    name: 'events',
                    title: 'Events',
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        title: Text(_presenter.maxEventCountTitle),
                        subtitle: Slider(
                          activeColor: Theme.of(context).accentColor,
                          label: _presenter.maxEventCountValueLabel,
                          min: 0,
                          max: _presenter.maxEventCountMaxValue,
                          value: _presenter.maxEventCountValue,
                          onChanged: (value) async =>
                              _presenter.onMaxEventCountChange(value),
                        ),
                      ),
                      Divider(),
                      ListTile(
                        title: const Text(
                            'Subscription watchdog interval (in seconds)'),
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
                        title: const Text('Show new event notification'),
                        trailing: Switch(
                            value: settings.showNewEventNotification,
                            onChanged: (value) =>
                                _presenter.toggleShowNewEventNotification()),
                        onTap: () =>
                            _presenter.toggleShowNewEventNotification(),
                      ),
                    ],
                  ),
                  _buildGroup(
                    name: 'dataTypes',
                    title: 'Data types',
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        title: const Text('Use internal viewers if possible'),
                        trailing: Switch(
                            value: settings.useInternalViewers,
                            onChanged: (value) =>
                                _presenter.toggleUseInternalViewers()),
                        onTap: () => _presenter.toggleUseInternalViewers(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: Text(_presenter.useInternalViewersTitle),
                        subtitle: Slider(
                          activeColor: Theme.of(context).accentColor,
                          label: _presenter.useInternalViewersValueLabel,
                          min: 0,
                          max: _presenter.useInternalViewersMaxValue,
                          value: _presenter.useInternalViewersValue,
                          onChanged: (value) async =>
                              _presenter.onUseInternalViewersChange(value),
                        ),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: const Text(
                            'Use scrollable indexed list (experimental)'),
                        trailing: Switch(
                            value: settings.useScrollableIndexedList,
                            onChanged: (value) =>
                                _presenter.toggleUseScrollableIndexedList()),
                        onTap: () =>
                            _presenter.toggleUseScrollableIndexedList(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: Text(_presenter
                            .drawingStrokeUpdateDeltaThresholdRatioTitle),
                        subtitle: Slider(
                          activeColor: Theme.of(context).accentColor,
                          label: _presenter
                              .drawingStrokeUpdateDeltaThresholdRatioValueLabel,
                          value:
                              settings.drawingStrokeUpdateDeltaThresholdRatio,
                          divisions: _presenter
                              .drawingStrokeUpdateDeltaThresholdRatioDivisions,
                          onChanged: (value) async => _presenter
                              .onDrawingStrokeUpdateDeltaThresholdRatioChange(
                                  value),
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
                        title: const Text('Cluster data markers'),
                        trailing: Switch(
                            value: settings.mapEnableClusterMarkers,
                            onChanged: (value) =>
                                _presenter.toggleMapEnableClusterMarkers()),
                        onTap: () => _presenter.toggleMapEnableClusterMarkers(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: const Text('Show marker badges'),
                        trailing: Switch(
                            value: settings.mapEnableMarkerBadges,
                            onChanged: (value) =>
                                _presenter.toggleMapEnableMarkerBadges()),
                        onTap: () => _presenter.toggleMapEnableMarkerBadges(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title:
                            const Text('Show current location (experimental)'),
                        trailing: Switch(
                            value: settings.mapEnableCurrentLocation,
                            onChanged: (value) =>
                                _presenter.toggleMapEnableCurrentLocation()),
                        onTap: () =>
                            _presenter.toggleMapEnableCurrentLocation(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: const Text('Follow current location'),
                        trailing: Switch(
                            value: settings.mapFollowCurrentLocation,
                            onChanged: (value) =>
                                _presenter.toggleMapFollowCurrentLocation()),
                        onTap: () =>
                            _presenter.toggleMapFollowCurrentLocation(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title: const Text('Full screen'),
                        trailing: Switch(
                            value: settings.mapFullScreen,
                            onChanged: (value) =>
                                _presenter.toggleMapFullScreen()),
                        onTap: () => _presenter.toggleMapFullScreen(),
                      ),
                    ],
                  ),
                  _buildGroup(
                    name: 'connections',
                    title: 'Connections',
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        title: const Text('Use authentication token'),
                        trailing: Switch(
                            value: settings.autoUseAuthToken,
                            onChanged: (value) =>
                                _presenter.toggleAutoUseAuthToken()),
                        onTap: () => _presenter.toggleAutoUseAuthToken(),
                      ),
                      _buildDivider(),
                      ListTile(
                        title:
                            const Text('Service discovery timeot (in seconds)'),
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
      onWillPop: () async {
        await _presenter.submit();
        return true;
      },
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
    return const Divider(
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
          const PopupMenuItem<String>(
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

    await _presenter.clearSettings();

    return true;
  }

  @override
  void refresh() {
    setState(() {});
  }
}
