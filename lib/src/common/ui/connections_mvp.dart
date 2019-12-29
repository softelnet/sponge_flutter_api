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
import 'package:sponge_flutter_api/src/common/ui/base_mvp.dart';

class ConnectionsViewModel extends BaseViewModel {
  List<SpongeConnection> connections;
  String activeConnectionName;
}

abstract class ConnectionsView extends BaseView {
  Future<SpongeConnection> addConnection();
  Future<SpongeConnection> editConnection(SpongeConnection connection);
}

class ConnectionsPresenter
    extends BasePresenter<ConnectionsViewModel, ConnectionsView> {
  ConnectionsPresenter(ConnectionsViewModel viewModel, ConnectionsView view)
      : super(viewModel, view);

  bool busy = false;

  void refreshModel() {
    viewModel.connections = service.connectionsConfiguration.getConnections();
    viewModel.activeConnectionName =
        service.connectionsConfiguration.getActiveConnectionName();
  }

  List<SpongeConnection> get connections => viewModel.connections;

  bool isConnectionActive(String connectionName) =>
      service.isConnectionActive(connectionName);

  Future<void> toggleActiveConnection(SpongeConnection connection) async {
    if (connection != null) {
      viewModel.activeConnectionName =
          viewModel.activeConnectionName != connection.name
              ? connection.name
              : null;
    }

    await service.setActiveConnection(viewModel.activeConnectionName);
  }

  void _setupData() {
    if (viewModel.activeConnectionName == null &&
        viewModel.connections.length == 1) {
      viewModel.activeConnectionName = viewModel.connections[0].name;
    } else if (viewModel.activeConnectionName != null &&
        viewModel.connections.isEmpty) {
      viewModel.activeConnectionName = null;
    }
  }

  Future<void> _commitData() async {
    _setupData();

    viewModel.connections.sort();

    await service.setConnections(
        viewModel.connections, viewModel.activeConnectionName);
  }

  Future<void> addConnection() async {
    var connection = await view.addConnection();
    if (connection != null) {
      viewModel.connections.add(connection);
      await _commitData();
    }
  }

  Future<SpongeConnection> editConnection(
      SpongeConnection editedConnection) async {
    var newConnection = await view.editConnection(editedConnection);

    if (newConnection != null) {
      int oldConnectionIndex = viewModel.connections
          .indexWhere((con) => con.name == editedConnection.name);
      if (oldConnectionIndex > -1) {
        viewModel.connections[oldConnectionIndex] = newConnection;
      }

      // Update the active connection name in case when the connection name has been changed.
      if (viewModel.activeConnectionName != null &&
          viewModel.activeConnectionName == editedConnection.name) {
        viewModel.activeConnectionName = newConnection.name;
      }

      await _commitData();
    }

    return newConnection;
  }

  Future<SpongeConnection> removeConnection(int index) async {
    SpongeConnection removedConnection = viewModel.connections.removeAt(index);

    if (viewModel.activeConnectionName != null &&
        viewModel.activeConnectionName == removedConnection.name) {
      viewModel.activeConnectionName = null;
    }

    await _commitData();

    return removedConnection;
  }
}
