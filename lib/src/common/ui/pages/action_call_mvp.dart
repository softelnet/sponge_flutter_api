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
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/bloc/provide_action_args_state.dart';
import 'package:sponge_flutter_api/src/common/model/action_call_session.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';
import 'package:sponge_flutter_api/src/common/util/model_utils.dart';
import 'package:sponge_flutter_api/src/common/util/type_gui_utils.dart';

class ActionCallViewModel extends BaseViewModel {
  ActionCallViewModel(this.actionData);

  ActionData actionData;
}

abstract class ActionCallView extends BaseView {
  void refresh();
  Future<void> refreshArgs({bool modal, bool showDialogOnError});
  Future<bool> saveForm();
  Future<void> onBeforeSubActionCall();
  Future<void> onAfterSubActionCall(ActionCallState state);
}

class ActionCallPresenter
    extends BasePresenter<ActionCallViewModel, ActionCallView> {
  ActionCallPresenter(ApplicationService service, ActionCallViewModel viewModel,
      ActionCallView view)
      : super(service, viewModel, view) {
    // Use a copy of the action data.
    viewModel.actionData = viewModel.actionData.clone();
  }

  bool busy = false;
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
    var postFrameRefreshCallback =
        () => WidgetsBinding.instance.addPostFrameCallback(
              (_) => view.refreshArgs(
                modal: false,
                showDialogOnError: false,
              ),
            );
    _session = ActionCallSession(
      service.spongeService,
      viewModel.actionData,
      onEventReceived: (event) => view.refreshArgs(
        modal: false,
        // TODO Is preventing error dialog in an event subscription OK? Maybe a snackbar should be shown.
        showDialogOnError: false,
      ),
      onEventError: postFrameRefreshCallback,
      onEventSubscriptionRenew: postFrameRefreshCallback,
      defaultPageableListPageSize: service.settings.defaultPageableListPageSize,
      verifyIsActive: verifyIsActive,
    );

    _session.open();

    _title = title;
    _bloc = bloc;
    _callImmediately = callImmediately;
  }

  void ensureRunning() {
    _session.ensureRunning();
  }

  Stream<ProvideActionArgsState> provideArgs() async* {
    yield* _session.provideArgs();
  }

  Future<bool> refreshAllowedProvidedArgs() async =>
      await _session.refreshAllowedProvidedArgs();

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
        view.refresh();
      }
    }
  }
}
