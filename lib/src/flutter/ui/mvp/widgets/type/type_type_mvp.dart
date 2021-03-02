// Copyright 2021 The Sponge authors.
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

import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';

class TypeTypeViewModel extends BaseViewModel {
  TypeTypeViewModel(this.uiContext);

  final UiContext uiContext;
}

abstract class TypeTypeView extends BaseView {}

class TypeTypePresenter extends BasePresenter<TypeTypeViewModel, TypeTypeView> {
  TypeTypePresenter(TypeTypeViewModel model, TypeTypeView view)
      : super(model.uiContext.service, model, view);

  @override
  FlutterApplicationService get service =>
      FlutterApplicationService.of(super.service);

  UiContext get uiContext => viewModel.uiContext;
}
