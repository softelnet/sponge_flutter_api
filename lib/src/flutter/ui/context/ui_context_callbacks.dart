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

import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';

abstract class UiContextCallbacks {
  void onSave(QualifiedDataType qType, dynamic value);
  void onUpdate(QualifiedDataType qType, dynamic value);
  void onActivate(QualifiedDataType qType, dynamic value);
  ProvidedValue onGetProvidedArg(QualifiedDataType qType);
  Future<void> onRefreshArgs();
  Future<bool> onSaveForm();
  Future<void> onBeforeSubActionCall();
  Future<void> onAfterSubActionCall(ActionCallState state);
  bool shouldBeEnabled(QualifiedDataType qType);
  PageableList getPageableList(QualifiedDataType qType);
  Future<void> fetchPageableListPage(QualifiedDataType qType);
  String getKey(String code);
  dynamic getRawValue(String path);

  void setAdditionalData(
      QualifiedDataType qType, String additionalDataKey, dynamic value);
  dynamic getAdditionalData(QualifiedDataType qType, String additionalDataKey);

  FlutterApplicationService get service;
}

class NoOpUiContextCallbacks implements UiContextCallbacks {
  NoOpUiContextCallbacks(this.service);

  @override
  final FlutterApplicationService service;

  @override
  void onSave(QualifiedDataType qType, dynamic value) {}

  @override
  void onUpdate(QualifiedDataType qType, dynamic value) {}

  @override
  void onActivate(QualifiedDataType qType, value) {}

  @override
  ProvidedValue onGetProvidedArg(QualifiedDataType qType) => null;

  @override
  bool shouldBeEnabled(QualifiedDataType qType) => true;

  @override
  Future<void> onRefreshArgs() async {}

  @override
  Future<bool> onSaveForm() async => true;

  @override
  Future<void> onAfterSubActionCall(ActionCallState state) async {}

  @override
  Future<void> onBeforeSubActionCall() async {}

  @override
  PageableList getPageableList(QualifiedDataType qType) => null;

  @override
  Future<void> fetchPageableListPage(QualifiedDataType qType) => null;

  @override
  String getKey(String code) => null;

  @override
  dynamic getRawValue(String path) => null;

  @override
  dynamic getAdditionalData(
          QualifiedDataType qType, String additionalDataKey) =>
      null;

  @override
  void setAdditionalData(
      QualifiedDataType qType, String additionalDataKey, value) {}
}
