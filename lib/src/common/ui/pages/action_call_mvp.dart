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
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_bloc.dart';
import 'package:sponge_flutter_api/src/common/model/action_call_session.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';
import 'package:sponge_flutter_api/src/common/util/model_utils.dart';
import 'package:sponge_flutter_api/src/common/util/type_gui_utils.dart';
import 'package:sponge_flutter_api/src/common/model/events.dart';

class ActionCallViewModel extends BaseViewModel {
  ActionCallViewModel(this.actionData);

  ActionData actionData;
}

abstract class ActionCallView extends BaseView {
  Future<void> refresh();
  Future<void> refreshArgs({bool showDialogOnError});
  Future<bool> saveForm();
  Future<void> onBeforeSubActionCall();
  Future<void> onAfterSubActionCall(AfterSubActionCallEvent event);
}

class ActionCallPresenter
    extends BasePresenter<ActionCallViewModel, ActionCallView> {
  ActionCallPresenter(ApplicationService service, ActionCallViewModel viewModel,
      ActionCallView view)
      : super(service, viewModel, view) {
    // Use a copy of the action data.
    viewModel.actionData = viewModel.actionData.clone();
  }

  bool get busy => calling || _session.blocking;
  bool calling = false;
  bool get callable => actionMeta.callable ?? true;

  ActionCallSession _session;

  ActionCallSession get session => _session;

  bool get anyArgSavedOrUpdated => _session.anyArgSavedOrUpdated;

  String _title;

  ActionCallBloc _bloc;
  ActionCallBloc get bloc => _bloc;

  bool _callImmediately;
  bool get callImmediately => _callImmediately;

  dynamic error;

  void init({
    @required bool verifyIsActive,
    @required String title,
    @required ActionCallBloc bloc,
    @required bool callImmediately,
  }) {
    _session = ActionCallSession(
      service.spongeService,
      viewModel.actionData,
      defaultPageableListPageSize: service.settings.defaultPageableListPageSize,
      verifyIsActive: verifyIsActive,
      // Refresh args in the next build.
      onEventError: () => WidgetsBinding.instance.addPostFrameCallback(
          (_) => view.refreshArgs(showDialogOnError: false)),
    );

    _session.open();

    _title = title;
    _bloc = bloc;
    _callImmediately = callImmediately;
  }

  void ensureRunning() {
    _session.ensureRunning();
  }

  ProvideActionArgsBloc get provideArgsBloc => _session.provideArgsBloc;

  Future<bool> refreshAllowedProvidedArgsSilently() async =>
      await _session.refreshAllowedProvidedArgsSilently();

  String get connectionName => service.spongeService?.connection?.name;

  ActionData get actionData => viewModel.actionData;

  ActionMeta get actionMeta => actionData.actionMeta;

  String get title =>
      _title ?? ModelUtils.getActionMetaDisplayLabel(actionData.actionMeta);

  void clearArgs() {
    _session.clearArgs();
  }

  bool get hasProvidedArgs => _session.hasProvidedArgs;

  bool get hasRefreshableArgs => _session.hasRefreshableArgs;

  void validateArgs() => service.spongeService.client
      .validateCallArgs(actionMeta, actionData.args);

  bool get showCall => ModelUtils.showCall(actionMeta);

  bool get showRefresh => ModelUtils.showRefresh(actionMeta);

  bool get showClear => ModelUtils.showClear(actionMeta);

  bool get showCancel => ModelUtils.showCancel(actionMeta);

  String get callLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_CALL_LABEL, () => 'RUN');

  String get refreshLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_REFRESH_LABEL, () => 'REFRESH');

  String get clearLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_CLEAR_LABEL, () => 'CLEAR');

  String get cancelLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_CANCEL_LABEL, () => 'CANCEL');

  void close() {
    _session.close();
  }

  bool isScrollable() {
    return !actionMeta.args
        .any((arg) => DataTypeGuiUtils.hasListTypeScroll(arg));
  }

  bool hasRootRecordSingleLeadingField() =>
      ModelUtils.getRootRecordSingleLeadingFieldByAction(actionData) != null;

  Future<bool> isActionActive() async => await _session.isActionActive();

  // Callbacks.
  @protected
  void onSaveOrUpdate(
      QualifiedDataType qType, dynamic value, bool refreshView) {
    if (_session.saveOrUpdate(qType, value)) {
      if (refreshView) {
        provideArgsBloc.provideArgs();
      }
    }
  }
}
