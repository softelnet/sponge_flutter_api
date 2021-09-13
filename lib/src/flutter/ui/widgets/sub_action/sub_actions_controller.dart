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
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/common/model/events.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/pages/action_call_page.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/action_call_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';

typedef OnBeforeSelectedSubActionCallback = Future<bool> Function(
    ActionData subActionData,
    SubActionType subActionType,
    dynamic contextValue);

typedef OnAfterSubActionCallCallback = Future<void> Function(
    AfterSubActionCallEvent event);

class SubActionRuntimeSpec {
  SubActionRuntimeSpec(this.spec, {this.active = true});

  final SubActionSpec spec;
  final bool active;
}

abstract class BaseActionsController {
  BaseActionsController({
    @required this.spongeService,
    @required this.parentFeatures,
    @required this.elementType,
    @required this.sourceTypeBundle,
  });

  final SpongeService spongeService;
  final Map<String, Object> parentFeatures;
  final DataType elementType;
  final RefTypeBundle sourceTypeBundle;

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
    spongeService.setupSubActionSpec(subActionSpec, elementType,
        sourceTypeBundle: sourceTypeBundle);
    return subActionSpec;
  }
}

class SubActionsController extends BaseActionsController {
  SubActionsController({
    @required SpongeService spongeService,
    @required Map<String, Object> parentFeatures,
    @required DataType elementType,
    @required RefTypeBundle sourceTypeBundle,
    @required this.onBeforeSelectedSubAction,
    @required this.onBeforeInstantCall,
    @required this.onAfterCall,
    this.propagateContextActions = false,
  }) : super(
          spongeService: spongeService,
          parentFeatures: parentFeatures,
          elementType: elementType,
          sourceTypeBundle: sourceTypeBundle,
        );

  final OnBeforeSelectedSubActionCallback onBeforeSelectedSubAction;
  final AsyncCallback onBeforeInstantCall;
  final OnAfterSubActionCallCallback onAfterCall;
  final bool propagateContextActions;

  factory SubActionsController.forRecord(
      UiContext uiContext, SpongeService spongeService) {
    var recordType = uiContext.qualifiedType.type as RecordType;

    return SubActionsController(
      spongeService: spongeService,
      parentFeatures: uiContext.features,
      elementType: recordType,
      // TODO No parent type for a record.
      sourceTypeBundle: RefTypeBundle(uiContext.callbacks.rootType, null),
      onBeforeSelectedSubAction: (ActionData subActionData,
          SubActionType subActionType, dynamic contextValue) async {
        if (subActionData.needsRunConfirmation) {
          if (!(await showConfirmationDialog(uiContext.context,
              'Do you want to run ${ModelUtils.getActionMetaDisplayLabel(subActionData.actionMeta)}?'))) {
            return false;
          }
        }

        return true;
      },
      onBeforeInstantCall: () async {
        await uiContext.callbacks.onBeforeSubActionCall();
      },
      onAfterCall: (event) async {
        var resultSubstitutionTarget =
            event.subActionSpec.subAction.result?.target;

        var state = event.state;

        // Handle sub-action result substitution.
        if (resultSubstitutionTarget != null &&
            state is ActionCallStateEnded &&
            state.resultInfo != null &&
            state.resultInfo.isSuccess) {
          var targetType = getResultSubstitutionTargetType(
              uiContext, resultSubstitutionTarget);

          var value = state.resultInfo.result;
          if (resultSubstitutionTarget != DataTypeConstants.PATH_THIS ||
              !DataTypeUtils.isNull(value)) {
            uiContext.callbacks.onSave(SaveValueEvent(targetType, value));
          }
        }

        await uiContext.callbacks.onAfterSubActionCall(event);
      },
    );
  }

  static QualifiedDataType getResultSubstitutionTargetType(
      UiContext uiContext, String resultSubstitutionTarget) {
    if (resultSubstitutionTarget == DataTypeConstants.PATH_THIS) {
      return uiContext.qualifiedType;
    } else if (DataTypeUtils.isPathRelativeToRoot(resultSubstitutionTarget)) {
      return QualifiedDataType(uiContext.callbacks.rootType,
          path: DataTypeUtils.getRootRelativePath(resultSubstitutionTarget));
    } else {
      return uiContext.qualifiedType.createChild(
          (uiContext.qualifiedType.type as RecordType)
              .getFieldType(resultSubstitutionTarget));
    }
  }

  factory SubActionsController.forList(
      UiContext uiContext, SpongeService spongeService) {
    var elementType = (uiContext.qualifiedType.type as ListType).elementType;

    return SubActionsController(
        spongeService: spongeService,
        parentFeatures: uiContext.features,
        elementType: elementType,
        sourceTypeBundle: RefTypeBundle(
            uiContext.callbacks.rootType, uiContext.qualifiedType.type),
        onBeforeSelectedSubAction: (ActionData subActionData,
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
        onBeforeInstantCall: () async {
          await uiContext.callbacks.onBeforeSubActionCall();
        },
        onAfterCall: (event) async {
          var resultSubstitutionTarget =
              event.subActionSpec.subAction.result?.target;
          var state = event.state;

          if (resultSubstitutionTarget != null &&
              state is ActionCallStateEnded &&
              state.resultInfo != null &&
              state.resultInfo.isSuccess) {
            if (resultSubstitutionTarget == DataTypeConstants.PATH_THIS) {
              Validate.notNull(
                  event.index, 'The list element index cannot be null');

              var value = state.resultInfo.result;
              if (!DataTypeUtils.isNull(value)) {
                (uiContext.value as List)[event.index] = value;
                // Save the whole list.
                uiContext.callbacks.onSave(
                    SaveValueEvent(uiContext.qualifiedType, uiContext.value));
              }
            } else if (resultSubstitutionTarget ==
                DataTypeConstants.PATH_PARENT) {
              var value = state.resultInfo.result;
              if (!DataTypeUtils.isNull(value)) {
                // Save the whole list.
                uiContext.callbacks
                    .onSave(SaveValueEvent(uiContext.qualifiedType, value));
              }
            } else if (DataTypeUtils.isPathRelativeToRoot(
                resultSubstitutionTarget)) {
              var value = state.resultInfo.result;
              if (!DataTypeUtils.isNull(value)) {
                // Save relative to the root.
                uiContext.callbacks.onSave(SaveValueEvent(
                  getResultSubstitutionTargetType(
                      uiContext, resultSubstitutionTarget),
                  value,
                ));
              }
            } else {
              throw Exception(
                  'The result substitution target $resultSubstitutionTarget is not supported for a list');
            }
          }

          await uiContext.callbacks.onAfterSubActionCall(event);
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
    List<SubActionSpec> specs,
    dynamic element, {
    @required int index,
    @required RefTypeValueBundle typeValueBundle,
  }) async {
    var entries = specs
        .map((spec) => IsActionActiveEntry(
            name: spec.actionName,
            args: ModelUtils.substituteSubActionArgs(
                spongeService, spec, elementType, element,
                sourceIndex: index,
                sourceTypeValueBundle: typeValueBundle,
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

  void setupSubAction(
    ActionData actionData,
    SubActionSpec subActionSpec,
    dynamic sourceValue,
    int sourceIndex,
    RefTypeValueBundle sourceTypeValueBundle,
  ) {
    if (subActionSpec.hasArgSubstitutions) {
      if (!actionData.hasCacheableContextArgs) {
        actionData.clear();
      }

      actionData.args = ModelUtils.substituteSubActionArgs(
          spongeService, subActionSpec, elementType, sourceValue,
          sourceIndex: sourceIndex,
          sourceTypeValueBundle: sourceTypeValueBundle,
          propagateContextActions: propagateContextActions);
    }
  }

  Future<void> onCreateElement(
    BuildContext context, {
    RefTypeValueBundle typeValueBundle,
  }) async {
    var createAction = getSubActionSpec(
        parentFeatures[Features.SUB_ACTION_CREATE_ACTION],
        SubActionType.create);
    if (createAction != null) {
      await _onElementSubAction(
        context: context,
        subActionSpec: createAction,
        setupCallback: (actionData) => setupSubAction(
            actionData, createAction, null, null, typeValueBundle),
      );
    }
  }

  Future<void> onReadElement(
    BuildContext context,
    dynamic value, {
    int index,
    RefTypeValueBundle typeValueBundle,
  }) async {
    var readAction = getSubActionSpec(
        getFeatures(value)[Features.SUB_ACTION_READ_ACTION],
        SubActionType.read);
    if (readAction != null) {
      await _onElementSubAction(
        context: context,
        subActionSpec: readAction,
        setupCallback: (actionData) => setupSubAction(
            actionData, readAction, value, index, typeValueBundle),
        value: value,
        index: index,
        readOnly: true,
      );
    }
  }

  Future<void> onUpdateElement(
    BuildContext context,
    dynamic value, {
    int index,
    RefTypeValueBundle typeValueBundle,
  }) async {
    var updateAction = getSubActionSpec(
        getFeatures(value)[Features.SUB_ACTION_UPDATE_ACTION],
        SubActionType.update);
    if (updateAction != null) {
      await _onElementSubAction(
        context: context,
        subActionSpec: updateAction,
        setupCallback: (actionData) => setupSubAction(
            actionData, updateAction, value, index, typeValueBundle),
        value: value,
        index: index,
      );
    }
  }

  Future<void> onDeleteElement(
    BuildContext context,
    dynamic value, {
    int index,
    RefTypeValueBundle typeValueBundle,
  }) async {
    var deleteAction = getSubActionSpec(
        getFeatures(value)[Features.SUB_ACTION_DELETE_ACTION],
        SubActionType.delete);
    if (deleteAction != null) {
      await _onElementSubAction(
        context: context,
        subActionSpec: deleteAction,
        setupCallback: (actionData) => setupSubAction(
            actionData, deleteAction, value, index, typeValueBundle),
        value: value,
        index: index,
      );
    }
  }

  Future<void> onActivateElement(
    BuildContext context,
    dynamic value, {
    int index,
    RefTypeValueBundle typeValueBundle,
  }) async {
    var activateAction = getSubActionSpec(
        getFeatures(value)[Features.SUB_ACTION_ACTIVATE_ACTION],
        SubActionType.activate);

    if (activateAction != null) {
      await _onElementSubAction(
        context: context,
        subActionSpec: activateAction,
        setupCallback: (actionData) => setupSubAction(
            actionData, activateAction, value, index, typeValueBundle),
        value: value,
        index: index,
      );
    }
  }

  Future<void> onElementContextAction(
    BuildContext context,
    SubActionSpec subActionSpec,
    dynamic value, {
    int index,
    RefTypeValueBundle typeValueBundle,
  }) async {
    await _onElementSubAction(
      context: context,
      subActionSpec: subActionSpec,
      setupCallback: (actionData) => setupSubAction(
          actionData, subActionSpec, value, index, typeValueBundle),
      value: value,
      index: index,
      header: value is AnnotatedValue ? value.valueLabel : null,
    );
  }

  Future<void> _onElementSubAction({
    @required BuildContext context,
    @required SubActionSpec subActionSpec,
    void Function(ActionData _) setupCallback,
    dynamic value,
    int index,
    bool readOnly = false,
    String header,
    bool showResultDialogIfNoResult = false,
  }) async {
    try {
      if (subActionSpec == null) {
        return;
      }

      var service = ApplicationProvider.of(context).service;

      if (onBeforeSelectedSubAction != null) {
        if (!(await onBeforeSelectedSubAction(
            service.spongeService
                .getCachedAction(subActionSpec.actionName, required: true),
            subActionSpec.type,
            value))) {
          return;
        }
      }

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

      bool subActionResultShown = false;

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

          subActionResultShown = true;
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

              subActionResultShown = true;
            }
          }

          callState = bloc.state.isFinal
              ? bloc.state
              : await bloc.stream.firstWhere((state) => state.isFinal,
                  orElse: () => null);
        }
      } finally {
        await onAfterCall?.call(AfterSubActionCallEvent(
          subActionSpec,
          callState,
          index: index,
          errorAlreadyHandled: subActionResultShown,
        ));

        await bloc.close();
      }
    } catch (e) {
      await handleError(context, e);
    }
  }

  /// Read, Update, Delete.
  List<SubActionSpec> _getRudActions(dynamic element) {
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
      dynamic value, int index, RefTypeValueBundle typeValueBundle) async {
    List<SubActionSpec> crudActionSpecs = _getRudActions(value);
    List<SubActionSpec> contextActionSpecs = _getContextActions(value);

    // Check actions for active/inactive.
    List<SubActionRuntimeSpec> runtimeSpecs = await getSubActionRuntimeSpecs(
      crudActionSpecs + contextActionSpecs,
      value,
      index: index,
      typeValueBundle: typeValueBundle,
    );

    if (crudActionSpecs.isNotEmpty && contextActionSpecs.isNotEmpty) {
      // Insert a separator between CRUD actions and context actions.
      runtimeSpecs.insert(crudActionSpecs.length, null);
    }

    return runtimeSpecs;
  }
}
