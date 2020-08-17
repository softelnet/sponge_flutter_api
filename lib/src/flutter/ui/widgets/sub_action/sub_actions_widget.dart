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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';
import 'package:sponge_flutter_api/src/common/util/model_utils.dart';
import 'package:sponge_flutter_api/src/external/async_popup_menu_button.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/model_gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/sub_action/sub_actions_controller.dart';

class SubActionsWidget extends StatefulWidget {
  SubActionsWidget({
    Key key,
    @required this.controller,
    @required this.value,
    this.index,
    this.parentType,
    this.parentValue,
    this.menuIcon,
    this.menuWidget,
    this.header,
    this.tooltip,
  }) : super(key: key);

  final SubActionsController controller;
  final dynamic value;
  final int index;
  final DataType parentType;
  final dynamic parentValue;

  final Widget menuIcon;
  final Widget menuWidget;
  final Widget header;
  final String tooltip;

  factory SubActionsWidget.forRecord(
    UiContext uiContext,
    SpongeService spongeService, {
    Key key,
    Widget menuIcon,
    Widget menuWidget,
    Widget header,
    String tooltip,
  }) {
    var controller = SubActionsController.forRecord(uiContext, spongeService);

    if (uiContext.enabled && controller.hasSubActions(uiContext.value)) {
      return SubActionsWidget(
        key: key,
        controller: controller,
        value: uiContext.value,
        menuIcon: menuIcon,
        menuWidget: menuWidget,
        header: header,
        tooltip: tooltip,
      );
    } else {
      return null;
    }
  }

  factory SubActionsWidget.forListElement(
    UiContext uiContext,
    SpongeService spongeService, {
    Key key,
    @required SubActionsController controller,
    @required dynamic element,
    @required int index,
    @required DataType parentType,
    @required dynamic parentValue,
    Widget menuIcon,
    Widget menuWidget,
    Widget header,
    String tooltip,
  }) {
    return SubActionsWidget(
      key: key ?? Key('sub-actions'),
      controller: controller,
      value: element,
      index: index,
      parentType: parentType,
      parentValue: parentValue,
      menuIcon: menuIcon,
      menuWidget: menuWidget,
      header: header,
      tooltip: tooltip,
    );
  }

  @override
  _SubActionsWidgetState createState() => _SubActionsWidgetState();
}

class _SubActionsWidgetState extends State<SubActionsWidget> {
  @override
  Widget build(BuildContext context) {
    return AsyncPopupMenuButton<SubActionSpec>(
        padding: EdgeInsets.zero,
        itemBuilder: (BuildContext context) =>
            _buildSubActionsMenuItems(context),
        onSelected: (subActionSpec) async => await _onSelectedSubAction(
            context,
            subActionSpec,
            widget.value,
            widget.index,
            widget.parentType,
            widget.parentValue),
        icon: widget.menuIcon,
        child: widget.menuWidget,
        tooltip: widget.tooltip,
    );
  }

  Future<List<PopupMenuEntry<SubActionSpec>>> _buildSubActionsMenuItems(
      BuildContext context) async {
    List<SubActionRuntimeSpec> runtimeSpecs = await widget.controller
        .getSubActionsRuntimeSpecs(
            widget.value, widget.index, widget.parentType, widget.parentValue);
    return [
      if (widget.header != null)
        PopupMenuItem<SubActionSpec>(
          child: widget.header,
          enabled: false,
        ),
      if (widget.header != null && runtimeSpecs.isNotEmpty)
        const PopupMenuDivider(),
      ...runtimeSpecs
          .map((runtimeSpec) => runtimeSpec != null
              ? _createSubActionMenuItem(context, runtimeSpec)
              : const PopupMenuDivider())
          .toList(),
    ];
  }

  PopupMenuEntry<SubActionSpec> _createSubActionMenuItem(
      BuildContext context, SubActionRuntimeSpec subActionRuntimeSpec) {
    var service = ApplicationProvider.of(context).service;
    var actionMeta = service.spongeService
        .getCachedAction(subActionRuntimeSpec.spec.actionName)
        .actionMeta;

    return PopupMenuItem<SubActionSpec>(
      value: subActionRuntimeSpec.spec,
      child: ListTile(
        leading: getActionIcon(context, service, actionMeta),
        title: Text(subActionRuntimeSpec.spec.subAction.label ??
            ModelUtils.getActionMetaDisplayLabel(actionMeta)),
        enabled: subActionRuntimeSpec.active,
      ),
      enabled: subActionRuntimeSpec.active,
    );
  }

  Future<void> _onSelectedSubAction(
      BuildContext context,
      SubActionSpec subActionSpec,
      dynamic element,
      int index,
      DataType parentType,
      dynamic parentValue) async {
    switch (subActionSpec.type) {
      case SubActionType.create:
        await widget.controller.onCreateElement(context,
            parentType: parentType, parentValue: parentValue);
        break;
      case SubActionType.read:
        await widget.controller.onReadElement(context, element,
            index: index, parentType: parentType, parentValue: parentValue);
        break;
      case SubActionType.update:
        await widget.controller.onUpdateElement(context, element,
            index: index, parentType: parentType, parentValue: parentValue);
        break;
      case SubActionType.delete:
        await widget.controller.onDeleteElement(context, element,
            index: index, parentType: parentType, parentValue: parentValue);
        break;
      case SubActionType.activate:
        await widget.controller.onActivateElement(context, element,
            index: index, parentType: parentType, parentValue: parentValue);
        break;
      case SubActionType.context:
        await widget.controller.onElementContextAction(
            context, subActionSpec, element,
            index: index, parentType: parentType, parentValue: parentValue);
        break;
    }
  }
}
