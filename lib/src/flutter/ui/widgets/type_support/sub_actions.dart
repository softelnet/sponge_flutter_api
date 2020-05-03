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
import 'package:sponge_flutter_api/src/common/bloc/action_call_bloc.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';
import 'package:sponge_flutter_api/src/common/util/model_utils.dart';
import 'package:sponge_flutter_api/src/external/async_popup_menu_button.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/pages/action_call_page.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/model_gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';

typedef BeforeSelectedSubActionCallback = Future<bool> Function(
    ActionData subActionData,
    SubActionType subActionType,
    dynamic contextValue);

typedef AfterSubActionCallCallback = Future<void> Function(
    SubActionSpec subActionSpec, ActionCallState actionCallState, int index);

class SubActionRuntimeSpec {
  SubActionRuntimeSpec(this.spec, {this.active = true});

  final SubActionSpec spec;
  final bool active;
}

class SubActionsWidget extends StatefulWidget {
  SubActionsWidget({
    Key key,
    @required this.controller,
    @required this.value,
    @required this.beforeSelectedSubAction,
    this.index,
    this.menuIcon,
    this.menuWidget,
    this.header,
    this.tooltip,
  }) : super(key: key);

  final SubActionsController controller;
  final dynamic value;
  final int index;
  final BeforeSelectedSubActionCallback beforeSelectedSubAction;

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
        beforeSelectedSubAction: (ActionData subActionData,
            SubActionType subActionType, dynamic contextValue) async {
          if (subActionData.needsRunConfirmation) {
            if (!(await showConfirmationDialog(uiContext.context,
                'Do you want to run ${ModelUtils.getActionMetaDisplayLabel(subActionData.actionMeta)}?'))) {
              return false;
            }
          }

          return true;
        },
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
      beforeSelectedSubAction: (ActionData subActionData,
          SubActionType subActionType, dynamic contextValue) async {
        if (subActionData.needsRunConfirmation) {
          String contextValueLabel =
              contextValue is AnnotatedValue ? contextValue.valueLabel : null;
          var confirmationQuestion;
          if (subActionType == SubActionType.delete) {
            confirmationQuestion =
                'Do you want to remove ${contextValueLabel ?? " the element"}?';
          } else {
            confirmationQuestion =
                'Do you want to run ${ModelUtils.getActionMetaDisplayLabel(subActionData.actionMeta)}?';
          }
          if (!(await showConfirmationDialog(
              uiContext.context, confirmationQuestion))) {
            return false;
          }
        }

        return true;
      },
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
    return Theme(
      data: Theme.of(context).copyWith(
          iconTheme: Theme.of(context)
              .iconTheme
              .copyWith(color: getButtonTextColor(context))),
      child: AsyncPopupMenuButton<SubActionSpec>(
        padding: EdgeInsets.zero,
        itemBuilder: (BuildContext context) =>
            _buildSubActionsMenuItems(context),
        onSelected: _onSelectedSubAction,
        icon: widget.menuIcon,
        child: widget.menuWidget,
        tooltip: widget.tooltip,
      ),
    );
  }

  Future<void> _onSelectedSubAction(SubActionSpec subActionSpec) async {
    try {
      if (widget.beforeSelectedSubAction != null) {
        var service = ApplicationProvider.of(context).service;

        if (!(await widget.beforeSelectedSubAction(
            service.spongeService
                .getCachedAction(subActionSpec.actionName, required: true),
            subActionSpec.type,
            widget.value))) {
          return;
        }
      }

      await widget.controller.onSelectedSubAction(
          context, subActionSpec, widget.value, widget.index);
    } catch (e) {
      await handleError(context, e);
    }
  }

  Future<List<PopupMenuEntry<SubActionSpec>>> _buildSubActionsMenuItems(
      BuildContext context) async {
    List<SubActionRuntimeSpec> runtimeSpecs =
        await widget.controller.getSubActionsRuntimeSpecs(widget.value);
    return [
      if (widget.header != null)
        PopupMenuItem<SubActionSpec>(
          child: widget.header,
          enabled: false,
        ),
      if (widget.header != null && runtimeSpecs.isNotEmpty) PopupMenuDivider(),
      ...runtimeSpecs
          .map((runtimeSpec) => runtimeSpec != null
              ? _createSubActionMenuItem(context, runtimeSpec)
              : PopupMenuDivider())
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
}

class BaseActionsController {
  BaseActionsController({
    @required this.spongeService,
    @required this.parentFeatures,
    @required this.elementType,
  });

  final SpongeService spongeService;
  final Map<String, Object> parentFeatures;
  final DataType elementType;

  Map<String, Object> getFeatures(dynamic element) => {}
    ..addAll(parentFeatures ?? {})
    ..addAll(element is AnnotatedValue ? element.features : {});

  SubActionSpec getSubActionSpec(
      SubAction subAction, SubActionType subActionType) {
    if (subAction == null) {
      return null;
    }

    var subActionSpec = SubActionSpec(subAction, subActionType);
    var subActionMeta = spongeService.getCachedAction(subActionSpec.actionName,
        required: false);
    if (subActionMeta == null) {
      return null;
    }
    spongeService.setupSubActionSpec(subActionSpec, elementType);
    return subActionSpec;
  }
}

class SubActionsController extends BaseActionsController {
  SubActionsController({
    @required SpongeService spongeService,
    @required Map<String, Object> parentFeatures,
    @required DataType elementType,
    @required this.onBeforeInstantCall,
    @required this.onAfterCall,
    this.propagateContextActions = false,
  }) : super(
            spongeService: spongeService,
            parentFeatures: parentFeatures,
            elementType: elementType);

  final AsyncCallback onBeforeInstantCall;
  final AfterSubActionCallCallback onAfterCall;
  final bool propagateContextActions;

  factory SubActionsController.forRecord(
      UiContext uiContext, SpongeService spongeService) {
    var recordType = uiContext.qualifiedType.type as RecordType;

    return SubActionsController(
      spongeService: spongeService,
      parentFeatures: uiContext.features,
      elementType: recordType,
      onBeforeInstantCall: () async {
        await uiContext.callbacks.onBeforeSubActionCall();
      },
      onAfterCall: (subActionSpec, state, index) async {
        var resultSubstitutionTarget = subActionSpec.subAction.result?.target;

        // Handle sub-action result substitution.
        if (resultSubstitutionTarget != null &&
            state is ActionCallStateEnded &&
            state.resultInfo != null &&
            state.resultInfo.isSuccess) {
          var parentType =
              resultSubstitutionTarget == DataTypeConstants.PATH_THIS
                  ? uiContext.qualifiedType
                  : uiContext.qualifiedType.createChild(
                      recordType.getFieldType(resultSubstitutionTarget));

          var value = state.resultInfo.result;
          if (resultSubstitutionTarget != DataTypeConstants.PATH_THIS ||
              !DataTypeUtils.isNull(value)) {
            uiContext.callbacks.onSave(parentType, value);
          }
        }

        await uiContext.callbacks.onAfterSubActionCall(state);
      },
    );
  }

  factory SubActionsController.forList(
      UiContext uiContext, SpongeService spongeService) {
    var elementType = (uiContext.qualifiedType.type as ListType).elementType;

    return SubActionsController(
        spongeService: spongeService,
        parentFeatures: uiContext.features,
        elementType: elementType,
        onBeforeInstantCall: () async {
          await uiContext.callbacks.onBeforeSubActionCall();
        },
        onAfterCall: (subActionSpec, state, index) async {
          var resultSubstitutionTarget = subActionSpec.subAction.result?.target;

          if (resultSubstitutionTarget != null &&
              state is ActionCallStateEnded &&
              state.resultInfo != null &&
              state.resultInfo.isSuccess) {
            Validate.isTrue(
                resultSubstitutionTarget == DataTypeConstants.PATH_THIS,
                'Only result substitution to \'this\' is supported for a list element');
            Validate.notNull(index, 'The list element index cannot be null');

            var value = state.resultInfo.result;
            if (!DataTypeUtils.isNull(value)) {
              (uiContext.value as List)[index] = value;
              // Save the whole list.
              uiContext.callbacks
                  .onSave(uiContext.qualifiedType, uiContext.value);
            }
          }

          await uiContext.callbacks.onAfterSubActionCall(state);
        });
  }

  bool hasSubActions(dynamic element) =>
      isReadEnabled(element) ||
      isUpdateEnabled(element) ||
      isDeleteEnabled(element) ||
      hasContextActions(element);

  bool hasContextActions(dynamic element) =>
      _getContextActions(element).isNotEmpty;

  List<SubActionSpec> _getContextActions(dynamic element) =>
      Features.getSubActions(getFeatures(element), Features.CONTEXT_ACTIONS)
          .map(
              (subAction) => getSubActionSpec(subAction, SubActionType.context))
          .where((subActionSpec) => subActionSpec != null)
          .toList();

  Future<List<SubActionRuntimeSpec>> getSubActionRuntimeSpecs(
      List<SubActionSpec> specs, dynamic element) async {
    var entries = specs
        .map((spec) => IsActionActiveEntry(
            name: spec.actionName,
            args: ModelUtils.substituteSubActionArgs(
                spongeService, spec, elementType, element,
                propagateContextActions: propagateContextActions,
                bestEffort: true),
            qualifiedVersion: spongeService
                .getCachedAction(spec.actionName)
                .actionMeta
                .qualifiedVersion))
        .toList();
    var active = await spongeService.client.isActionActive(entries);

    var result = <SubActionRuntimeSpec>[];
    for (var i = 0; i < specs.length; i++) {
      result.add(SubActionRuntimeSpec(specs[i], active: active[i]));
    }

    return result;
  }

  bool isCreateEnabled() =>
      getSubActionSpec(parentFeatures[Features.SUB_ACTION_CREATE_ACTION],
          SubActionType.create) !=
      null;

  bool isReadEnabled(dynamic element) =>
      getSubActionSpec(getFeatures(element)[Features.SUB_ACTION_READ_ACTION],
          SubActionType.read) !=
      null;

  bool isUpdateEnabled(dynamic element) =>
      getSubActionSpec(getFeatures(element)[Features.SUB_ACTION_UPDATE_ACTION],
          SubActionType.update) !=
      null;

  bool isDeleteEnabled(dynamic element) =>
      getSubActionSpec(getFeatures(element)[Features.SUB_ACTION_DELETE_ACTION],
          SubActionType.delete) !=
      null;

  bool isActivateEnabled(dynamic element) =>
      getSubActionSpec(
          getFeatures(element)[Features.SUB_ACTION_ACTIVATE_ACTION],
          SubActionType.activate) !=
      null;

  String getCreateActionName() => getSubActionSpec(
          parentFeatures[Features.SUB_ACTION_CREATE_ACTION],
          SubActionType.create)
      ?.actionName;

  Future<void> onSelectedSubAction(BuildContext context,
      SubActionSpec selectedValue, dynamic element, int index) async {
    switch (selectedValue.type) {
      case SubActionType.create:
        break;
      case SubActionType.read:
        await onReadElement(context, element, index: index);
        break;
      case SubActionType.update:
        await onUpdateElement(context, element, index: index);
        break;
      case SubActionType.delete:
        await onDeleteElement(context, element, index: index);
        break;
      case SubActionType.activate:
        await onActivateElement(context, element, index: index);
        break;
      case SubActionType.context:
        await onElementContextAction(context, selectedValue, element,
            index: index);
        break;
    }
  }

  void setupSubAction(
      ActionData actionData, SubActionSpec subActionSpec, dynamic sourceValue) {
    if (subActionSpec.hasArgSubstitutions) {
      if (!actionData.hasCacheableContextArgs) {
        actionData.clear();
      }

      actionData.args = ModelUtils.substituteSubActionArgs(
          spongeService, subActionSpec, elementType, sourceValue,
          propagateContextActions: propagateContextActions);
    }
  }

  Future<void> onCreateElement(BuildContext context) async {
    var createAction = getSubActionSpec(
        parentFeatures[Features.SUB_ACTION_CREATE_ACTION],
        SubActionType.create);
    // A create CRUD action doesn't support arg substitutions.
    await _onElementSubAction(
      context: context,
      subActionSpec: createAction,
    );
  }

  Future<void> onReadElement(BuildContext context, dynamic value,
      {int index}) async {
    var readAction = getSubActionSpec(
        getFeatures(value)[Features.SUB_ACTION_READ_ACTION],
        SubActionType.read);
    if (readAction != null) {
      await _onElementSubAction(
        context: context,
        subActionSpec: readAction,
        setupCallback: (actionData) =>
            setupSubAction(actionData, readAction, value),
        index: index,
        readOnly: true,
      );
    }
  }

  Future<void> onUpdateElement(BuildContext context, dynamic value,
      {int index}) async {
    var updateAction = getSubActionSpec(
        getFeatures(value)[Features.SUB_ACTION_UPDATE_ACTION],
        SubActionType.update);
    if (updateAction != null) {
      await _onElementSubAction(
        context: context,
        subActionSpec: updateAction,
        setupCallback: (actionData) =>
            setupSubAction(actionData, updateAction, value),
        index: index,
      );
    }
  }

  Future<void> onDeleteElement(BuildContext context, dynamic value,
      {int index}) async {
    var deleteAction = getSubActionSpec(
        getFeatures(value)[Features.SUB_ACTION_DELETE_ACTION],
        SubActionType.delete);
    if (deleteAction != null) {
      await _onElementSubAction(
        context: context,
        subActionSpec: deleteAction,
        setupCallback: (actionData) =>
            setupSubAction(actionData, deleteAction, value),
        index: index,
      );
    }
  }

  Future<void> onActivateElement(BuildContext context, dynamic value,
      {int index}) async {
    var activateAction = getSubActionSpec(
        getFeatures(value)[Features.SUB_ACTION_ACTIVATE_ACTION],
        SubActionType.activate);

    if (activateAction != null) {
      await _onElementSubAction(
        context: context,
        subActionSpec: activateAction,
        setupCallback: (actionData) =>
            setupSubAction(actionData, activateAction, value),
        index: index,
      );
    }
  }

  Future<void> onElementContextAction(
      BuildContext context, SubActionSpec subActionSpec, dynamic value,
      {int index}) async {
    await _onElementSubAction(
      context: context,
      subActionSpec: subActionSpec,
      setupCallback: (actionData) =>
          setupSubAction(actionData, subActionSpec, value),
      index: index,
      header: value is AnnotatedValue ? value.valueLabel : null,
    );
  }

  Future<void> _onElementSubAction({
    @required BuildContext context,
    @required SubActionSpec subActionSpec,
    void Function(ActionData _) setupCallback,
    int index,
    bool readOnly = false,
    String header,
    bool showResultDialogIfNoResult = false,
  }) async {
    if (subActionSpec != null) {
      var service = ApplicationProvider.of(context).service;

      // Check if the action exists.
      ActionData actionData =
          await service.spongeService.getAction(subActionSpec.actionName);
      // Use a clone if there are argument substitutions.
      if (subActionSpec.hasArgSubstitutions) {
        actionData = actionData.clone();
      }

      setupCallback?.call(actionData);

      var bloc = ActionCallBloc(
        spongeService: service.spongeService,
        actionName: subActionSpec.actionName,
        saveState: actionData.hasCacheableContextArgs,
      );

      ActionCallState callState;

      var showActionCallWidget = actionData.hasVisibleArgs;

      try {
        if (showActionCallWidget) {
          // Call the sub-action in the ActionCall screen.
          var newActionData = await showActionCall(
            context,
            actionData,
            builder: (context) => ActionCallPage(
              actionData: actionData,
              readOnly: readOnly,
              bloc: bloc,
              callImmediately: true,
              showResultDialog: !subActionSpec.hasResultSubstitution,
              showResultDialogIfNoResult: showResultDialogIfNoResult,
              verifyIsActive: false,
              header: header,
              title: subActionSpec.subAction.label,
            ),
          );
          callState = newActionData != null
              ? ActionCallStateEnded(newActionData.resultInfo)
              : null;
        } else {
          bool autoClosing = !showResultDialogIfNoResult &&
              actionData.actionMeta.result is VoidType &&
              actionData.actionMeta.result?.label == null;

          if (autoClosing) {
            await onBeforeInstantCall?.call();
          }

          bloc.add(actionData.args);

          if (!autoClosing) {
            if (!subActionSpec.hasResultSubstitution) {
              await showActionResultDialog(
                context: context,
                actionData: actionData,
                bloc: bloc,
                autoClosing: autoClosing,
              );
            }
          }

          callState = await bloc.firstWhere((state) => state.isFinal,
              orElse: () => null);
        }
      } finally {
        await onAfterCall?.call(subActionSpec, callState, index);

        await bloc.close();
      }
    }
  }

  List<SubActionSpec> _getCrudActions(dynamic element) {
    var crudActionSpecs = <SubActionSpec>[];

    var readAction = getSubActionSpec(
        getFeatures(element)[Features.SUB_ACTION_READ_ACTION],
        SubActionType.read);
    if (readAction != null) {
      crudActionSpecs.add(readAction);
    }

    var updateAction = getSubActionSpec(
        getFeatures(element)[Features.SUB_ACTION_UPDATE_ACTION],
        SubActionType.update);
    if (updateAction != null) {
      crudActionSpecs.add(updateAction);
    }

    var deleteAction = getSubActionSpec(
        getFeatures(element)[Features.SUB_ACTION_DELETE_ACTION],
        SubActionType.delete);
    if (deleteAction != null) {
      crudActionSpecs.add(deleteAction);
    }

    return crudActionSpecs;
  }

  Future<List<SubActionRuntimeSpec>> getSubActionsRuntimeSpecs(
      dynamic value) async {
    List<SubActionSpec> crudActionSpecs = _getCrudActions(value);
    List<SubActionSpec> contextActionSpecs = _getContextActions(value);

    // Check actions for active/inactive.
    List<SubActionRuntimeSpec> runtimeSpecs = await getSubActionRuntimeSpecs(
        crudActionSpecs + contextActionSpecs, value);

    if (crudActionSpecs.isNotEmpty && contextActionSpecs.isNotEmpty) {
      // Insert a separator between CRUD actions and context actions.
      runtimeSpecs.insert(crudActionSpecs.length, null);
    }

    return runtimeSpecs;
  }
}
