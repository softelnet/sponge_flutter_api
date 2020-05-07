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
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';
import 'package:sponge_flutter_api/src/common/util/model_utils.dart';

typedef OnRefreshCallback = void Function();

class ConnectionsViewModel extends BaseViewModel {
  List<SpongeConnection> connections;
  String activeConnectionName;
}

abstract class ConnectionsView extends BaseView {
  Future<SpongeConnection> addConnection();
  Future<SpongeConnection> editConnection(SpongeConnection connection);

  void refresh([OnRefreshCallback callback]);
}

class ConnectionsPresenter
    extends BasePresenter<ConnectionsViewModel, ConnectionsView> {
  ConnectionsPresenter(ApplicationService service,
      ConnectionsViewModel viewModel, ConnectionsView view)
      : super(service, viewModel, view);

  bool busy = false;

  void refreshModel() {
    viewModel.connections = service.connectionsConfiguration.getConnections();
    viewModel.activeConnectionName =
        service.connectionsConfiguration.getActiveConnectionName();
  }

  List<SpongeConnection> get connections => viewModel.connections;

  List<SpongeConnection> getFilteredConnections(
      bool isFilterByNetwork, NetworkStatus networkStatus) {
    return viewModel.connections
        .where((connection) =>
            !isFilterByNetwork ||
            ModelUtils.shouldConnectionBeFiltered(connection, networkStatus))
        .toList();
  }

  bool isConnectionActive(String connectionName) =>
      service.isConnectionActive(connectionName);

  Future<bool> toggleActiveConnection(SpongeConnection connection) async {
    bool activate = viewModel.activeConnectionName != connection.name;

    viewModel.activeConnectionName = activate ? connection.name : null;

    await service.setActiveConnection(viewModel.activeConnectionName);

    return activate;
  }

  Future<void> _commitData() async {
    if (viewModel.activeConnectionName != null &&
        viewModel.connections.isEmpty) {
      viewModel.activeConnectionName = null;
    }

    viewModel.connections.sort();

    await service.setConnections(
        viewModel.connections, viewModel.activeConnectionName);
  }

  Future<void> showAddConnection() async {
    var connection = await view.addConnection();
    if (connection != null) {
      viewModel.connections.add(connection);
      await _commitData();
    }
  }

  Future<SpongeConnection> showEditConnection(
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

  Future<SpongeConnection> removeConnection(String name) async {
    var removedConnection = viewModel.connections.firstWhere(
        (connection) => connection.name == name,
        orElse: () => null);
    if (removedConnection != null) {
      viewModel.connections.remove(removedConnection);

      if (viewModel.activeConnectionName != null &&
          viewModel.activeConnectionName == removedConnection.name) {
        viewModel.activeConnectionName = null;
      }

      await _commitData();
    }

    return removedConnection;
  }

  void refresh([OnRefreshCallback callback]) {
    if (isBound) {
      view.refresh(callback);
    }
  }

  Future<void> addConnections(List<SpongeConnection> connections) async {
    if (connections.isNotEmpty) {
      viewModel.connections.addAll(connections);
      await _commitData();
    }
  }
}
