// Copyright 2018 The Sponge authors.
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

import 'package:sponge_flutter_api/src/common/service/application_service.dart';

abstract class BaseViewModel {}

abstract class BaseView {}

abstract class BasePresenter<M extends BaseViewModel, V extends BaseView> {
  BasePresenter(this.viewModel, this.view);

  M viewModel;
  V view;

  ApplicationService _service;
  ApplicationService get service => _service;

  void setService(ApplicationService service) => _service = service;

  void updateModel(M viewModel) => this.viewModel = viewModel;
}
