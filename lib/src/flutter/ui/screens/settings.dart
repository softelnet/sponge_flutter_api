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
import 'package:sponge_flutter_api/src/flutter/mobile_constants.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/state_container.dart';
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

  MobileApplicationSettings get settings =>
      StateContainer.of(context).service.settings;

  @override
  Widget build(BuildContext context) {
    _textViewerWidthSliderValue ??=
        StateContainer.of(context).service.settings.textViewerWidth ?? 0;
    if (_textViewerWidthSliderValue > MAX_TEXT_VIEWER_WIDTH_SLIDER_VALUE) {
      _textViewerWidthSliderValue = MAX_TEXT_VIEWER_WIDTH_SLIDER_VALUE;
    }

    _maxEventCountSliderValue ??=
        (StateContainer.of(context).service.settings.maxEventCount ?? 0) ~/
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
        ),
        body: SafeArea(
          child: Builder(
            builder: (BuildContext context) => Container(
              margin: const EdgeInsets.only(top: 20.0, bottom: 20.0),
              child: ListView(
                children: <Widget>[
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text('Dark theme'),
                          trailing: Switch(
                            value:
                                Theme.of(context).brightness == Brightness.dark,
                            onChanged: (value) => _toggleTheme(context),
                          ),
                          onTap: () => _toggleTheme(context),
                        ),
                      ],
                    ),
                  ),
                  Divider(),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                              'Show tabs for action categories and knowledge bases'),
                          trailing: Switch(
                              value: settings.tabsInActionList,
                              onChanged: (value) => _toggleTabsInActionList()),
                          onTap: () => _toggleTabsInActionList(),
                        ),
                        Divider(),
                        ListTile(
                          title: Text(
                              'Action call simplified by a tap on an item'),
                          trailing: Switch(
                              value: settings.actionCallOnTap,
                              onChanged: (value) => _toggleActionCallOnTap()),
                          onTap: () => _toggleActionCallOnTap(),
                        ),
                        Divider(),
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
                        Divider(),
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
                        Divider(),
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
                        Divider(),
                        ListTile(
                          title: Text('Use internal viewers if possible'),
                          trailing: Switch(
                              value: settings.useInternalViewers,
                              onChanged: (value) =>
                                  _toggleUseInternalViewers()),
                          onTap: () => _toggleUseInternalViewers(),
                        ),
                        Divider(),
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
                                _textViewerWidthSliderValue?.roundToDouble() ??
                                    0,
                            onChanged: (value) async {
                              setState(() =>
                                  _textViewerWidthSliderValue = value.toInt());
                              await settings.setTextViewerWidth(value.toInt());
                            },
                          ),
                        ),
                        // TODO Remove drawAntiAliasing.
                        // Divider(),
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
                  ),
                  Card(
                    child: Column(
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
                            max: MAX_MAX_EVENT_COUNT_SLIDER_VALUE
                                .roundToDouble(),
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
                          title: Text(
                              'Subscription watchdog interval (in seconds)'),
                          subtitle: TextField(
                            keyboardType: TextInputType.number,
                            controller: _subscriptionWatchdogIntervalController,
                            onChanged: (value) async {
                              await settings.setSubscriptionWatchdogInterval(
                                  int.parse(value));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text('Automatically use authentication token'),
                          trailing: Switch(
                              value: settings.autoUseAuthToken,
                              onChanged: (value) => _toggleAutoUseAuthToken()),
                          onTap: () => _toggleAutoUseAuthToken(),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text('Reset to defaults'),
                          onTap: () => _resetToDefaults(context),
                          trailing: IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () => _resetToDefaults(context)),
                        ),
                      ],
                    ),
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

  Future<void> _toggleTabsInActionList() async {
    await settings.setTabsInActionList(!settings.tabsInActionList);
    setState(() {});
  }

  Future<void> _toggleActionCallOnTap() async {
    await settings.setActionCallOnTap(!settings.actionCallOnTap);
    setState(() {});
  }

  Future<void> _toggleUseInternalViewers() async {
    await settings.setUseInternalViewers(!settings.useInternalViewers);
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
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text(
            'Settings have been reset to the default values',
          ),
          backgroundColor: Colors.red,
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

    await StateContainer.of(context).service.clearConfiguration();
    return true;
  }

  Future<bool> _submit() async {
    StateContainer.of(context).service.spongeService?.maxEventCount =
        _maxEventCountSliderValue * MAX_EVENT_COUNT_RATIO;

    return true;
  }
}
