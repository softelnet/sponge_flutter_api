import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_bloc.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/action_call.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/external/async_popup_menu_button.dart';
import 'package:sponge_flutter_api/src/util/utils.dart';

typedef BeforeSelectedSubActionCallback = Future<bool> Function(
    ActionData subActionData,
    SubActionType subActionType,
    dynamic contextValue);

class SubActionsWidget extends StatefulWidget {
  SubActionsWidget({
    Key key,
    @required this.controller,
    @required this.value,
    @required this.beforeSelectedSubAction,
    this.index,
  }) : super(key: key);

  final SubActionsController controller;
  final dynamic value;
  final int index;
  final BeforeSelectedSubActionCallback beforeSelectedSubAction;

  factory SubActionsWidget.ofUiContext(
      UiContext uiContext, SpongeService spongeService) {
    var controller = SubActionsController.ofUiContext(uiContext, spongeService);

    if (uiContext.enabled && controller.hasSubActions(uiContext.value)) {
      return SubActionsWidget(
        controller: controller,
        value: uiContext.value,
        beforeSelectedSubAction: (ActionData subActionData,
            SubActionType subActionType, dynamic contextValue) async {
          if (subActionData.needsRunConfirmation) {
            if (!(await showConfirmationDialog(uiContext.context,
                'Do you want to run ${getActionMetaDisplayLabel(subActionData.actionMeta)}?'))) {
              return false;
            }
          }

          return true;
        },
      );
    } else {
      return null;
    }
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
    return runtimeSpecs
        .map((runtimeSpec) => runtimeSpec != null
            ? _createSubActionMenuItem(context, runtimeSpec)
            : PopupMenuDivider())
        .toList();
  }

  PopupMenuEntry<SubActionSpec> _createSubActionMenuItem(
      BuildContext context, SubActionRuntimeSpec subActionRuntimeSpec) {
    var service = ApplicationProvider.of(context).service;
    var actionMeta = service.spongeService
        .getCachedAction(subActionRuntimeSpec.spec.actionName)
        .actionMeta;
    var iconData = getActionIconData(service, actionMeta);

    return PopupMenuItem<SubActionSpec>(
      value: subActionRuntimeSpec.spec,
      child: ListTile(
        leading: iconData != null
            ? Icon(iconData, color: getIconColor(context))
            : null,
        title: Text(getActionMetaDisplayLabel(actionMeta)),
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
      String expression, SubActionType subActionType) {
    if (expression == null) {
      return null;
    }

    var subActionSpec = SubActionSpec.parse(expression, subActionType);
    var subActionMeta = spongeService.getCachedAction(subActionSpec.actionName,
        required: false);
    if (subActionMeta == null) {
      return null;
    }
    spongeService.setupSubActionSpec(subActionSpec, elementType);
    return subActionSpec;
  }
}

typedef AfterSubActionCallCallback = Future<void> Function(
    SubActionSpec subActionSpec, ActionCallState actionCallState, int index);

class SubActionRuntimeSpec {
  SubActionRuntimeSpec(this.spec, {this.active = true});

  final SubActionSpec spec;
  final bool active;
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

  factory SubActionsController.ofUiContext(
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
        // Handle sub-action result substitution.
        if (subActionSpec.resultSubstitution != null &&
            state is ActionCallStateEnded &&
            state.resultInfo != null &&
            state.resultInfo.isSuccess) {
          var parentType = subActionSpec.resultSubstitution ==
                  DataTypeUtils.THIS
              ? uiContext.qualifiedType
              : uiContext.qualifiedType.createChild(
                  recordType.getFieldType(subActionSpec.resultSubstitution));

          var value = state.resultInfo.result;
          if (subActionSpec.resultSubstitution != DataTypeUtils.THIS ||
              !DataTypeUtils.isNull(value)) {
            uiContext.callbacks.onSave(parentType, value);
          }
        }

        await uiContext.callbacks.onAfterSubActionCall(state);
      },
    );
  }

  bool hasSubActions(dynamic element) =>
      isReadEnabled(element) ||
      isUpdateEnabled(element) ||
      isDeleteEnabled(element) ||
      hasContextActions(element);

  bool hasContextActions(dynamic element) =>
      getContextActions(element).isNotEmpty;

  List<SubActionSpec> getContextActions(dynamic element) =>
      Features.getStringList(getFeatures(element), Features.CONTEXT_ACTIONS)
          .map((actionSpecString) =>
              getSubActionSpec(actionSpecString, SubActionType.context))
          .where((subActionSpec) => subActionSpec != null)
          .toList();

  Future<List<SubActionRuntimeSpec>> getActiveContextActions(
      dynamic element) async {
    var specs = getContextActions(element);
    var entries = specs
        .map((spec) => IsActionActiveEntry(
            name: spec.actionName,
            args: _substituteArgs(spec, elementType, element, bestEffort: true),
            qualifiedVersion: spongeService
                .getCachedAction(spec.actionName)
                .actionMeta
                .qualifiedVersion))
        .toList();
    var active = await spongeService.client.isActionActive(entries);

    List<SubActionRuntimeSpec> result = [];
    for (int i = 0; i < specs.length; i++) {
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

  // void _validateSubActionArgs(ActionMeta actionMeta) {
  //   // TODO More strict action arg validation.
  //   var expectedTypeKind = elementType.kind;
  //   Validate.isTrue(
  //       actionMeta.args.isNotEmpty &&
  //           actionMeta.args[0].kind == expectedTypeKind,
  //           'The first argument of ${actionMeta.name} action should be $expectedTypeKind');
  // }

  // TODO Doesn't run if create, so create doesn't support substitutions.
  void setupSubAction(
      ActionData actionData, SubActionSpec subActionSpec, dynamic sourceValue) {
    if (subActionSpec.hasArgSubstitutions) {
      if (!actionData.hasCacheableContextArgs) {
        actionData.clear();
      }

      actionData.args =
          _substituteArgs(subActionSpec, elementType, sourceValue);
    }
  }

  Future<void> onCreateElement(BuildContext context) async {
    await _onElementSubAction(
      context: context,
      subActionSpec: getSubActionSpec(
          parentFeatures[Features.SUB_ACTION_CREATE_ACTION],
          SubActionType.create),
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
    // TODO implement busy state
    if (subActionSpec != null) {
      var service = ApplicationProvider.of(context).service;

      // Check if the action exists.
      ActionData actionData =
          await service.spongeService.getAction(subActionSpec.actionName);
      // Use a clone if there are argument substitutions.
      if (subActionSpec.hasArgSubstitutions) {
        actionData = actionData.copy();
      }

      if (setupCallback != null) {
        setupCallback(actionData);
      }

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
          var newActionData = await showActionCall(context, actionData,
              builder: (context) => ActionCallPage(
                    actionData: actionData,
                    readOnly: readOnly,
                    bloc: bloc,
                    callImmediately: true,
                    showResultDialog: subActionSpec.resultSubstitution == null,
                    showResultDialogIfNoResult: showResultDialogIfNoResult,
                    verifyIsActive: false,
                    header: header,
                  ));
          callState = newActionData != null
              ? ActionCallStateEnded(newActionData.resultInfo)
              : null;
        } else {
          // await callActionImmediately(
          //   context: context,
          //   onBeforeCall: () => setState(() => _busy = true),
          //   onAfterCall: () => setState(() => _busy = false),
          //   actionData: actionData,
          //   bloc: bloc,
          //   showNoResultDialog: showNoResultDialog,
          // );

          bool autoClosing = !showResultDialogIfNoResult &&
              actionData.actionMeta.result is VoidType &&
              actionData.actionMeta.result?.label == null;

          if (autoClosing && onBeforeInstantCall != null) {
            // TODO If no dialog will be shown, show simple HUD.
            await onBeforeInstantCall();
          }

          bloc.add(actionData.args);

          if (!autoClosing) {
            if (subActionSpec.resultSubstitution == null) {
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
        // TODO Always refreshes. Maybe feature "refreshAfterCall"?
        if (onAfterCall != null) {
          await onAfterCall(subActionSpec, callState, index);
        }

        bloc.close();
      }
    }
  }

  // TODO Move to common.
  List<dynamic> _substituteArgs(
      SubActionSpec subActionSpec, DataType sourceType, dynamic sourceValue,
      {bool bestEffort = false}) {
    ActionMeta subActionMeta =
        spongeService.getCachedAction(subActionSpec.actionName).actionMeta;
    var subActionData = ActionData(subActionMeta);

    bool showActionCallWidget = subActionMeta.args.length >
        (subActionSpec.argSubstitutions?.length ?? 1);

    if (subActionSpec.argSubstitutions == null) {
      // The default behavior that sets the first arg of the sub-action, if any.
      if (subActionMeta.args.isNotEmpty) {
        try {
          // TODO More strict action arg validation.
          Validate.isTrue(subActionMeta.args[0].kind == sourceType.kind,
              'The first argument of ${subActionMeta.name} action should be ${sourceType.kind}');
          subActionData.args[0] = DataTypeUtils.cloneValue(sourceValue);
        } catch (e) {
          if (!bestEffort) {
            rethrow;
          }
        }
      }
    } else {
      for (int i = 0; i < subActionData.args.length; i++) {
        var subArgType = subActionMeta.args[i];

        var subActionArgSpec = subActionSpec.argSubstitutions.firstWhere(
            (substitution) => substitution.target == subArgType.name,
            orElse: () => null);
        if (subActionArgSpec != null) {
          try {
            subActionData.args[i] = DataTypeUtils.cloneValue(
                DataTypeUtils.getSubValue(sourceValue, subActionArgSpec.source,
                    unwrapAnnotatedTarget: false, unwrapDynamicTarget: false));
          } catch (e) {
            if (!bestEffort) {
              rethrow;
            }
          }
        }
      }
    }

    if (!bestEffort) {
      for (int i = 0; i < subActionData.args.length; i++) {
        var subArgType = subActionMeta.args[i];

        var subActionArgSpec = subActionSpec.argSubstitutions?.firstWhere(
            (substitution) => substitution.target == subArgType.name,
            orElse: () => null);

        // Exception if the target argument is not visible, not nullable and substituted by null.
        Validate.isTrue(
            Features.getOptional(
                        subArgType.features, Features.VISIBLE, () => true) &&
                    showActionCallWidget ||
                subArgType.nullable ||
                DataTypeUtils.hasAllNotNullValuesSet(
                    subArgType, subActionData.args[i]),
            // TODO Support context actions in dynamic types.
            subActionArgSpec != null
                ? 'The argument \'${getSafeTypeDisplayLabel(DataTypeUtils.getSubType(sourceType, subActionArgSpec.source, null))}\' is not set properly'
                : 'The sub-action argument \'${getSafeTypeDisplayLabel(subArgType)}\' is not set properly');
      }
    }

    // Do not propagate context actions to sub-actions.
    subActionData.args = subActionData.args.map((arg) {
      if (arg is AnnotatedValue && !propagateContextActions) {
        arg = AnnotatedValue.of(arg)
          ..features
              .removeWhere((name, value) => name == Features.CONTEXT_ACTIONS);
      }

      return arg;
    }).toList();

    return subActionData.args;
  }

  Future<List<SubActionRuntimeSpec>> getSubActionsRuntimeSpecs(
      dynamic value) async {
    List<SubActionRuntimeSpec> specs = [];

    var readAction = getSubActionSpec(
        getFeatures(value)[Features.SUB_ACTION_READ_ACTION],
        SubActionType.read);
    if (readAction != null) {
      specs.add(SubActionRuntimeSpec(readAction));
    }

    var updateAction = getSubActionSpec(
        getFeatures(value)[Features.SUB_ACTION_UPDATE_ACTION],
        SubActionType.update);
    if (updateAction != null) {
      specs.add(SubActionRuntimeSpec(updateAction));
    }

    var deleteAction = getSubActionSpec(
        getFeatures(value)[Features.SUB_ACTION_DELETE_ACTION],
        SubActionType.delete);
    if (deleteAction != null) {
      specs.add(SubActionRuntimeSpec(deleteAction));
    }

    // TODO Support for active/inactive CRUD actions.

    List<SubActionRuntimeSpec> contextActionRuntimeSpecs =
        await getActiveContextActions(value);

    if (contextActionRuntimeSpecs.isNotEmpty) {
      if (specs.isNotEmpty) {
        specs.add(null);
      }

      contextActionRuntimeSpecs.forEach(
          (contextActionRuntimeSpec) => specs.add(contextActionRuntimeSpec));
    }

    return specs;
  }
}
