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
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';

class MapTypeViewModel extends BaseViewModel {
  MapTypeViewModel(this.uiContext);

  final UiContext uiContext;
}

abstract class MapTypeView extends BaseView {}

class MapTypePresenter extends BasePresenter<MapTypeViewModel, MapTypeView> {
  MapTypePresenter(MapTypeViewModel model, MapTypeView view)
      : super(model.uiContext.service, model, view);

  @override
  FlutterApplicationService get service =>
      FlutterApplicationService.of(super.service);

  UiContext get uiContext => viewModel.uiContext;

  MapType get type => uiContext.qualifiedType.type;

  String get label => uiContext.getDecorationLabel();

  Map get valueMap => uiContext.value as Map;

  String get keyLabel => type.keyType.label;

  String get valueLabel => type.valueType.label;
}
