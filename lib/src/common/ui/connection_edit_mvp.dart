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

import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';
import 'package:sponge_flutter_api/src/common/ui/base_mvp.dart';

class ConnectionEditViewModel extends BaseViewModel {
  ConnectionEditViewModel(this.originalConnection)
      : connection = originalConnection == null
            ? SpongeConnection(anonymous: true)
            : SpongeConnection.of(originalConnection);

  final SpongeConnection originalConnection;
  SpongeConnection connection;
}

abstract class ConnectionEditView extends BaseView {}

class ConnectionEditPresenter
    extends BasePresenter<ConnectionEditViewModel, ConnectionEditView> {
  ConnectionEditPresenter(
      ConnectionEditViewModel viewModel, ConnectionEditView view)
      : super(viewModel, view);

  bool busy = false;

  bool get editing => viewModel.originalConnection != null;

  SpongeConnection get originalConnection => viewModel.originalConnection;

  SpongeConnection get connection => viewModel.connection;

  String get name => viewModel.connection.name;
  set name(String value) => viewModel.connection.name = value?.trim();
  String validateName(String value) {
    value = value?.trim();

    if (value.isEmpty) {
      return 'The connection name must not be empty';
    }

    if (service.connectionsConfiguration
        .getConnections()
        .any((con) => con.name == value)) {
      return 'A connection with that name already exists';
    }

    return null;
  }

  String get url => viewModel.connection.url;
  set url(String value) => viewModel.connection.url = value?.trim();
  String validateUrl(String value) =>
      value.isEmpty ? 'The Sponge address must not be empty' : null;

  String get network => viewModel.connection.network;
  set network(String value) => viewModel.connection.network = value?.trim();

  bool get anonymous => viewModel.connection.anonymous;
  set anonymous(bool value) {
    viewModel.connection.anonymous = value;
  }

  String get username => viewModel.connection.username;
  set username(String value) => viewModel.connection.username =
      value != null && value.trim().isNotEmpty ? value.trim() : null;
  String validateUsername(String value) =>
      !anonymous && value.isEmpty ? 'The user name must not be empty' : null;

  String get password => viewModel.connection.password;
  set password(String value) => viewModel.connection.password =
      value != null && value.trim().isNotEmpty ? value.trim() : null;
  String validatePassword(String value) => !anonymous && value.isEmpty
      ? 'The user password must not be empty'
      : null;

  bool get savePassword => viewModel.connection.savePassword;
  set savePassword(bool value) => viewModel.connection.savePassword = value;

  Future<String> testConnection() async =>
      await SpongeService.testConnection(viewModel.connection);
}
