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
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:recase/recase.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/flutter/compatibility/compatibility_mobile.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/state_container.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/action_call.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/type/generic_type.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> handleError(BuildContext context, e,
    {bool logStackTrace = true}) async {
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

/// A static set containing build contexts that have modal error dialogs open.
Set<BuildContext> _showingModalDialogContext = Set();

T doInCallback<T>(BuildContext context, T operation(),
    {bool showDialogOnError = true,
    bool logStackTrace = true,
    bool rethrowError = true}) {
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
    BuildContext context, FutureOr<T> computation(),
    {bool showDialogOnError = true,
    bool logStackTrace = true,
    bool rethrowError = true}) async {
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

// This code is a copy from: https://github.com/flutter/flutter/blob/master/examples/flutter_gallery/lib/gallery/about.dart
class LinkTextSpan extends TextSpan {
  LinkTextSpan({TextStyle style, String url, String text})
      : super(
            style: style,
            text: text ?? url,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                launch(url, forceSafariVC: false);
              });
}

IconData getActionArgsIconData(int size) {
  switch (size) {
    case 0:
      return Icons.filter_none;
    case 1:
      return Icons.filter_1;
    case 2:
      return Icons.filter_2;
    case 3:
      return Icons.filter_3;
    case 4:
      return Icons.filter_4;
    case 5:
      return Icons.filter_5;
    case 6:
      return Icons.filter_6;
    case 7:
      return Icons.filter_7;
    case 8:
      return Icons.filter_8;
    case 9:
      return Icons.filter_9;
    default:
      return Icons.filter_9_plus;
  }
}

Color string2color(String colorRgbHex) => colorRgbHex != null
    ? convertFromColor(GenericColor.fromHexString(colorRgbHex))
    : null;

String color2string(Color color) =>
    color != null ? convertToColor(color).toHexString() : null;

Color getContrastColor(Color color) {
  // Using YIQ color space.
  double y = (299 * color.red + 587 * color.green + 114 * color.blue) / 1000;
  return y >= 128 ? Colors.black : Colors.white;
}

Color getIconColor(BuildContext context) =>
    Theme.of(context).accentColor.withAlpha(200);

Color getFloatingButtonBackgroudColor(BuildContext context) =>
    getSecondaryColor(context).withOpacity(0.80);

Color getSecondaryColor(BuildContext context) => Colors.orange[300];

Color getTextColor(BuildContext context) =>
    Theme.of(context).primaryTextTheme.body1.color;

Color getThemedBackgroundColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).canvasColor
        : Theme.of(context).primaryColorDark.withAlpha(100);

Color getCallIconColor(BuildContext context) =>
    Theme.of(context).accentColor.withAlpha(120);

bool isDarkTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color getButtonTextColor(BuildContext context) => Theme.of(context).accentColor;

TextStyle getButtonTextStyle(BuildContext context) =>
    TextStyle(color: getButtonTextColor(context));

TextStyle getArgLabelTextStyle(BuildContext context) =>
    Theme.of(context).textTheme.caption;

String getValueLabel(dynamic value) =>
    (value != null && value is AnnotatedValue) ? value.valueLabel : null;

String getValueDescription(dynamic value) =>
    (value != null && value is AnnotatedValue) ? value.valueDescription : null;

IconData getActionIconDataByActionName(
    FlutterApplicationService service, String actionName) {
  var actionMeta = service.spongeService.getCachedAction(actionName).actionMeta;

  return getActionIconData(service, actionMeta);
}

IconData getActionIconData(
    FlutterApplicationService service, ActionMeta actionMeta) {
  return getIconData(service, actionMeta.features[Features.ICON]);
}

IconData getIconData(FlutterApplicationService service, String iconName) {
  if (iconName != null) {
    var iconData = service.icons[ReCase(iconName).camelCase];
    if (iconData?.codePoint != null) {
      return iconData;
    }
  }

  return null;
}

Future<void> showDistinctScreen(BuildContext context, String name) async {
  await Navigator.pushNamedAndRemoveUntil(
      context, name, ModalRoute.withName(name));
}

Future<void> showChildScreen(BuildContext context, String name) async {
  await Navigator.popAndPushNamed(context, name);
}

class SpinningWidget extends AnimatedWidget {
  const SpinningWidget({
    Key key,
    @required AnimationController controller,
    @required this.child,
  }) : super(key: key, listenable: controller);

  final Widget child;

  Animation<double> get _progress => listenable;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: _progress.value * 2.0 * math.pi,
        child: child,
      );
}

class ColoredTabBar extends StatelessWidget implements PreferredSizeWidget {
  ColoredTabBar({this.color, @required this.child});

  final Color color;
  final TabBar child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) => Container(
        color: color,
        child: child,
      );
}

typedef OnSwipePopCallback = void Function();

class SwipePopDetector extends StatefulWidget {
  SwipePopDetector({
    Key key,
    @required this.child,
    this.onSwipe,
    this.ratio = 0.2,
  })  : assert(child != null),
        assert(ratio != null),
        super(key: key);

  final Widget child;
  final OnSwipePopCallback onSwipe;
  final double ratio;

  @override
  _SwipePopDetectorState createState() => _SwipePopDetectorState();
}

class _SwipePopDetectorState extends State<SwipePopDetector> {
  double dx = 0;

  @override
  Widget build(BuildContext context) {
    // Swipe disabled.
    if (widget.ratio == 0 || widget.onSwipe == null) {
      return widget.child;
    }

    return GestureDetector(
      child: widget.child,
      onPanStart: (details) => dx = 0,
      onPanUpdate: (details) {
        if (details.delta.dx > 0) {
          dx += details.delta.dx;

          var minDx = MediaQuery.of(context).size.width * widget.ratio;

          if (dx >= minDx) {
            widget.onSwipe();
          }
        } else if (details.delta.dx < 0) {
          dx = 0;
        }
      },
      onPanEnd: (details) {
        dx = 0;
      },
    );
  }
}

Future<void> showEventHandlerActionById(
    BuildContext context, String eventId) async {
  var service = StateContainer.of(context).service;
  EventData eventData = service.spongeService.getEvent(eventId);

  if (eventData != null) {
    await showEventHandlerAction(context, eventData);
  }
}

Future<void> showEventHandlerAction(
    BuildContext context, EventData eventData) async {
  var service = StateContainer.of(context).service;
  ActionData handlerActionData =
      await service.spongeService.findEventHandlerAction(eventData);

  if (handlerActionData != null) {
    ActionData resultActionData = await showActionCall(
      context,
      handlerActionData,
      builder: (context) => ActionCallWidget(
        actionData: handlerActionData,
        bloc: service.spongeService
            .getActionCallBloc(handlerActionData.actionMeta.name),
        callImmediately: true,
        showResultDialogIfNoResult: false,
      ),
    );

    if (resultActionData != null) {
      service.spongeService.removeEvent(eventData.event.id);
    }
  }
}

String createDataTypeKeyValue(QualifiedDataType qType) => 'value-${qType.path}';
