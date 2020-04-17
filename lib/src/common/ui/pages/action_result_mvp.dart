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
import 'package:sponge_flutter_api/src/common/bloc/action_call_bloc.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';

class ActionResultViewModel extends BaseViewModel {
  ActionResultViewModel(this.actionData, this.bloc);
  final ActionData actionData;
  final ActionCallBloc bloc;
}

abstract class ActionResultView extends BaseView {}

class ActionResultPresenter
    extends BasePresenter<ActionResultViewModel, ActionResultView> {
  ActionResultPresenter(ApplicationService service, ActionResultViewModel model, ActionResultView view)
      : super(service, model, view);

  ActionData get actionData => viewModel.actionData;
  ActionCallBloc get bloc => viewModel.bloc;

  String get resultLabel => actionData.actionMeta.result?.label ?? 'Result';
}
