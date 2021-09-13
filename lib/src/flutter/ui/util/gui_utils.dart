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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/service/exceptions.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';

Future<void> handleError(
  BuildContext context,
  dynamic e, {
  bool logStackTrace = true,
}) async {
  final _logger = Logger('HandleError');
  if (logStackTrace) {
    _logger.severe(
        'Error in ${context?.widget?.runtimeType}', e, StackTrace.current);
  } else {
    _logger.severe('Error in ${context?.widget?.runtimeType}', e);
  }

  if (!_showingModalDialogContext.contains(context)) {
    _showingModalDialogContext.add(context);
    try {
      await showErrorDialog(context, e.toString());
    } finally {
      _showingModalDialogContext.remove(context);
    }
  }
}

Future<void> handleConnectionError(BuildContext context, dynamic error) async {
  if (error is UsernamePasswordNotSetException) {
    await showWarningDialog(context, error.toString());
  } else {
    await handleError(context, error);
  }
}

/// A static set containing build contexts that have modal error dialogs open.
Set<BuildContext> _showingModalDialogContext = {};

T doInCallback<T>(
  BuildContext context,
  T Function() operation, {
  bool showDialogOnError = true,
  bool logStackTrace = true,
  bool rethrowError = true,
}) {
  try {
    return operation();
  } catch (e) {
    if (showDialogOnError) {
      handleError(context, e, logStackTrace: logStackTrace);
    }
    if (rethrowError) {
      rethrow;
    } else {
      return null;
    }
  }
}

FutureOr<T> doInCallbackAsync<T>(
  BuildContext context,
  FutureOr<T> Function() computation, {
  bool showDialogOnError = true,
  bool logStackTrace = true,
  bool rethrowError = true,
}) async {
  try {
    return await computation();
  } catch (e) {
    if (showDialogOnError) {
      await handleError(context, e, logStackTrace: logStackTrace);
    }
    if (rethrowError) {
      rethrow;
    } else {
      return null;
    }
  }
}

Future<void> showDistinctScreen(BuildContext context, String name) async {
  await Navigator.pushNamedAndRemoveUntil(
      context, name, ModalRoute.withName(name));
}

Future<void> showChildScreen(BuildContext context, String name) async {
  await Navigator.popAndPushNamed(context, name);
}

PageRoute<T> createPageRoute<T>(
  BuildContext context, {
  @required WidgetBuilder builder,
  String title,
  RouteSettings settings,
  bool maintainState = true,
  bool fullscreenDialog = false,
}) =>
    ApplicationProvider.of(context).service.settings.actionSwipeToClose
        ? CupertinoPageRoute<T>(
            builder: builder,
            title: title,
            settings: settings,
            maintainState: maintainState,
            fullscreenDialog: fullscreenDialog)
        : MaterialPageRoute<T>(
            builder: builder,
            settings: settings,
            maintainState: maintainState,
            fullscreenDialog: fullscreenDialog);

Color getPrimaryColor(BuildContext context) => Theme.of(context).accentColor;

Color getPrimaryDarkerColor(BuildContext context) =>
    Theme.of(context).colorScheme.primary;

Color getIconColor(BuildContext context) =>
    Theme.of(context).accentColor.withAlpha(200);

Color getFloatingButtonBackgroudColor(BuildContext context) =>
    getSecondaryColor(context).withOpacity(0.80);

Color getSecondaryColor(BuildContext context) => Colors.orange[300];

Color getThemedBackgroundColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).canvasColor
        : Theme.of(context).primaryColorDark.withAlpha(100);

Color getBorderColor(BuildContext context) =>
    Theme.of(context).dividerColor.withAlpha(15);

Color getCallIconColor(BuildContext context) =>
    Theme.of(context).accentColor.withAlpha(120);

bool isDarkTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color getButtonTextColor(BuildContext context) => Theme.of(context).accentColor;

Color getContrastColor(Color color) {
  // Using YIQ color space.
  double y = (299 * color.red + 587 * color.green + 114 * color.blue) / 1000;
  return y >= 128 ? Colors.black : Colors.white;
}

TextStyle getButtonTextStyle(BuildContext context) =>
    TextStyle(color: getButtonTextColor(context));

TextStyle getArgLabelTextStyle(BuildContext context) =>
    Theme.of(context).textTheme.caption;

IconData getPopupMenuIconData(BuildContext context) {
  var platform = Theme.of(context).platform;

  assert(platform != null);
  switch (platform) {
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return Icons.more_vert;
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return Icons.more_horiz;
    default:
      return Icons.more_vert;
  }
}

Icon getPopupMenuIcon(BuildContext context) {
  var iconData = getPopupMenuIconData(context);

  return iconData != null ? Icon(iconData) : null;
}

typedef GetProvidedArgCallback = ProvidedValue Function(
    QualifiedDataType qType);

Widget createClearableTextFieldSuffixIcon(
    BuildContext context, TextEditingController controller) {
  return createClearableFieldSuffixIcon(
    context,
    onClear: () => WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.clear(),
    ),
  );
}

Widget createClearableFieldSuffixIcon(
  BuildContext context, {
  @required Function() onClear,
}) {
  return InkResponse(
    key: Key('text-clear'),
    child: Icon(
      MdiIcons.close,
      color: Colors.grey,
      size: getArgLabelTextStyle(context).fontSize * 1.5,
    ),
    onTap: () => onClear?.call(),
  );
}

Future<bool> setPreferenceStringNullable(
    SharedPreferences prefs, String key, String value) async {
  if (value != null) {
    return await prefs.setString(key, value);
  } else {
    return await prefs.remove(key);
  }
}

Future<bool> setPreferenceBoolNullable(
    SharedPreferences prefs, String key, bool value) async {
  if (value != null) {
    return await prefs.setBool(key, value);
  } else {
    return await prefs.remove(key);
  }
}

Future<bool> setPreferenceStringListNullable(
    SharedPreferences prefs, String key, List<String> value) async {
  if (value != null) {
    return await prefs.setStringList(key, value);
  } else {
    return await prefs.remove(key);
  }
}
