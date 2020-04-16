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

import 'package:logging/logging.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/sponge_flutter_api.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/ui/pages/action_call_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/model/flutter_model.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';

class FlutterActionCallPresenter extends ActionCallPresenter
    implements UiContextCallbacks {
  FlutterActionCallPresenter(ActionCallViewModel viewModel, ActionCallView view)
      : super(viewModel, view);

  static final Logger _logger = Logger('FlutterActionCallPresenter');

  @override
  void onSave(QualifiedDataType qType, dynamic value) {
    onSaveOrUpdate(qType, value, true);
  }

  @override
  void onUpdate(QualifiedDataType qType, dynamic value) {
    bool responsive = DataTypeUtils.getFeatureOrProperty(
        qType.type, value, Features.RESPONSIVE, () => false);

    onSaveOrUpdate(qType, value, responsive);
  }

  @override
  void onActivate(QualifiedDataType qType, value) {
    if (session.activate(qType, value)) {
      view.refresh();
    }
  }

  @override
  ProvidedValue onGetProvidedArg(QualifiedDataType qType) =>
      session.getProvidedArg(qType);

  @override
  bool shouldBeEnabled(QualifiedDataType qType) =>
      session.shouldBeEnabled(qType);

  @override
  Future<void> onRefresh() async => view.refresh();

  @override
  Future<void> onRefreshArgs() async {
    await view.refreshArgs();
  }

  @override
  Future<bool> onSaveForm() async => await view.saveForm();

  @override
  Future<void> onBeforeSubActionCall() async {
    await view.onBeforeSubActionCall();
  }

  @override
  Future<void> onAfterSubActionCall(ActionCallState state) async {
    await view.onAfterSubActionCall(state);
  }

  @override
  PageableList getPageableList(QualifiedDataType qType) =>
      actionData.getPageableList(qType.path);

  @override
  Future<void> fetchPageableListPage(QualifiedDataType listQType) async =>
      await session.fetchPageableListPage(listQType);

  @override
  String getKey(String code) {
    if (code == null) {
      return null;
    }

    try {
      return actionData.getArgValueByName(code,
          unwrapAnnotatedTarget: true, unwrapDynamicTarget: true);
    } catch (e) {
      // Only log the exception.
      _logger.severe('getKey error for \'$code\'', e);
      return null;
    }
  }

  @override
  dynamic getAdditionalData(
          QualifiedDataType qType, String additionalDataKey) =>
      (actionData as FlutterActionData)
          .getAdditionalArgData(qType.path, additionalDataKey);

  @override
  void setAdditionalData(
      QualifiedDataType qType, String additionalDataKey, dynamic value) {
    (actionData as FlutterActionData)
        .setAdditionalArgData(qType.path, additionalDataKey, value);
  }

  @override
  FlutterApplicationService get service => super.service;

  bool get canSwipeToClose =>
      // TODO Is checking the record single leading field for swipe to close ok? Swipe should be disabled for maps.
      service.settings.actionSwipeToClose &&
      !(ModelUtils.getRootRecordSingleLeadingFieldByAction(actionData)
              ?.features
              ?.containsKey(Features.GEO_MAP) ??
          false);
}
