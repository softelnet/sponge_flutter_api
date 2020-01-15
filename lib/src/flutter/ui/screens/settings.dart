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

import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:flutter/material.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/gui_constants.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';

class SettingsWidget extends StatefulWidget {
  SettingsWidget({Key key}) : super(key: key);

  @override
  createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  int _textViewerWidthSliderValue;
  static const MAX_TEXT_VIEWER_WIDTH_SLIDER_VALUE = 10;
  int _maxEventCountSliderValue;
  static const MAX_MAX_EVENT_COUNT_SLIDER_VALUE = 10;
  static const MAX_EVENT_COUNT_RATIO = 10;

  TextEditingController _subscriptionWatchdogIntervalController;

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
                children: <Widget>[
                  _buildGroup(
                    name: 'theme',
                    title: 'Theme',
                    initiallyExpanded: true,
                    children: [
                      ListTile(
                        title: Text('Dark theme'),
                        trailing: Switch(
                          value:
                              Theme.of(context).brightness == Brightness.dark,
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
                              'setting-setSubscriptionWatchdogInterval'),
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
                          label: 'a$_textViewerWidthSliderValue',
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
                      // TODO Remove drawAntiAliasing.
                      // _buildDivider(),
                      // ListTile(
                      //   title: Text(
                      //       'Anti-aliasing in drawings (may cause issues on Android)'),
                      //   trailing: Switch(
                      //       value: settings.drawAntiAliasing,
                      //       onChanged: (value) =>
                      //           _toggleDrawAntiAliasing()),
                      //   onTap: () => _toggleDrawAntiAliasing(),
                      // ),
                    ],
                  ),
                  _buildGroup(
                    name: 'security',
                    title: 'Security',
                    initiallyExpanded: false,
                    children: [
                      ListTile(
                        title: Text('Use authentication token'),
                        trailing: Switch(
                            value: settings.autoUseAuthToken,
                            onChanged: (value) => _toggleAutoUseAuthToken()),
                        onTap: () => _toggleAutoUseAuthToken(),
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
            child: Text('Reset settings and connections'),
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

  // TODO Remove drawAntiAliasing.
  // Future<void> _toggleDrawAntiAliasing() async {
  //   await settings.setDrawAntiAliasing(!settings.drawAntiAliasing);
  //   setState(() {});
  // }

  Future<void> _toggleAutoUseAuthToken() async {
    await settings.setAutoUseAuthToken(!settings.autoUseAuthToken);
    setState(() {});
  }

  void _toggleTheme(BuildContext context) {
    DynamicTheme.of(context).setBrightness(
        isDarkTheme(context) ? Brightness.light : Brightness.dark);
  }

  Future<void> _resetToDefaults(BuildContext context) async {
    try {
      bool cleared = await _clearConfiguration(context);
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

  Future<bool> _clearConfiguration(BuildContext context) async {
    if (!await showConfirmationDialog(context,
        'Do you want to reset the current settings (including the configured connections)?')) {
      return false;
    }

    await ApplicationProvider.of(context).service.clearConfiguration();
    return true;
  }

  Future<bool> _submit() async {
    ApplicationProvider.of(context).service.spongeService?.maxEventCount =
        _maxEventCountSliderValue * MAX_EVENT_COUNT_RATIO;

    return true;
  }
}
