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

import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';

class LoginData {
  LoginData({this.username, this.password});

  String username;
  String password;
}

class LoginViewModel extends BaseViewModel {
  LoginViewModel(this.connectionName);

  final String connectionName;
}

abstract class LoginView extends BaseView {}

class LoginPresenter extends BasePresenter<LoginViewModel, LoginView> {
  LoginPresenter(
      ApplicationService service, LoginViewModel model, LoginView view)
      : super(service, model, view);

  final _loginData = LoginData();

  String get username => _loginData.username;
  set username(String value) => _loginData.username = value;

  String get password => _loginData.password;
  set password(String value) => _loginData.password = value;

  String get title => 'Log in to ${viewModel.connectionName}';

  LoginData get loginData => _loginData;

  Future<void> logIn() async {
    service.spongeService.connection.username = _loginData.username;
    service.spongeService.connection.password = _loginData.password;

    await service.spongeService.getVersion();
  }
}
