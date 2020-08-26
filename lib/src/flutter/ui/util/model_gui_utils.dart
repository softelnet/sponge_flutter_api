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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recase/recase.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/model/type/generic_type.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/compatibility/generic_type_conversions.dart';
import 'package:sponge_flutter_api/src/flutter/gui_factory.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/pages/action_call_page.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/action_call_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/widgets.dart';

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

Icon getActionIconByActionName(BuildContext context,
    FlutterApplicationService service, String actionName) {
  var actionMeta = service.spongeService.getCachedAction(actionName).actionMeta;

  return getActionIcon(context, service, actionMeta);
}

Icon getActionIcon(BuildContext context, FlutterApplicationService service,
    ActionMeta actionMeta) {
  var iconInfo = Features.getIcon(actionMeta.features);
  var iconData = getIconData(service, iconInfo?.name);

  if (iconData == null) {
    return null;
  }

  return Icon(
    iconData,
    color: string2color(iconInfo?.color) ?? getIconColor(context),
    size: iconInfo?.size,
  );
}

Widget getIcon(
  BuildContext context,
  FlutterApplicationService service,
  IconInfo iconInfo, {
  IconData Function() orIconData,
  double forcedSize,
  EdgeInsetsGeometry imagePadding,
}) {
  if (iconInfo?.url != null) {
    var image =
        Provider.of<SpongeGuiFactory>(context).createNetworkImage(iconInfo.url);

    var box = forcedSize != null
        ? SizedBox(child: image, width: forcedSize, height: forcedSize)
        : image;

    return imagePadding != null
        ? Padding(
            child: box,
            padding: imagePadding,
          )
        : box;
  }

  var iconData = getIconData(service, iconInfo?.name) ?? orIconData?.call();

  if (iconData == null) {
    return null;
  }

  return Icon(
    iconData,
    color: string2color(iconInfo?.color) ?? getIconColor(context),
    size: iconInfo?.size ?? forcedSize,
  );
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

Future<void> showEventHandlerActionById(
    BuildContext context, String eventId) async {
  var service = ApplicationProvider.of(context).service;
  EventData eventData = service.spongeService.getEvent(eventId);

  if (eventData != null) {
    await showEventHandlerAction(context, eventData);
  }
}

Future<void> showEventHandlerAction(
    BuildContext context, EventData eventData) async {
  var service = ApplicationProvider.of(context).service;
  ActionData handlerActionData =
      await service.spongeService.findEventHandlerAction(eventData);

  if (handlerActionData != null) {
    ActionData resultActionData = await showActionCall(
      context,
      handlerActionData,
      builder: (context) => ActionCallPage(
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

String createDataTypeKeyValue(
  QualifiedDataType qType, {
  String qualifier,
}) =>
    qType?.path != null
        ? 'value-${qType.path}${qualifier != null ? "-" + qualifier : ""}'
        : null;

Key createDataTypeKey(
  QualifiedDataType qType, {
  String qualifier,
}) {
  var value = createDataTypeKeyValue(
    qType,
    qualifier: qualifier,
  );

  return value != null ? Key(value) : null;
}

Future<void> navigateToExtendedViewer(
    TypeGuiProvider provider, TypeViewerContext viewerContext) async {
  var viewer = provider.createExtendedViewer(viewerContext);
  if (viewer != null) {
    await Navigator.push(
      viewerContext.context,
      createPageRoute(
        viewerContext.context,
        builder: (context) => SwipeDetector(
          child: viewer,
          onSwipe: (context) => Navigator.pop(context),
        ),
      ),
    );
  }
}

Alignment getAlignment(Map<String, Object> features) {
  switch (features[Features.ALIGN]) {
    case Features.ALIGN_CENTER:
      return Alignment.center;
    case Features.ALIGN_RIGHT:
      return Alignment.centerRight;
    default:
      return Alignment.centerLeft;
  }
}
