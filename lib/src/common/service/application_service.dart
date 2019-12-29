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

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/application_constants.dart';
import 'package:sponge_flutter_api/src/common/configuration/connections_configuration.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';

enum ActionIconsView { custom, internal, none }
enum ActionsOrder { defaultOrder, alphabetical }

abstract class ApplicationSettings {
  ActionIconsView get actionIconsView;
  ActionsOrder get actionsOrder;
  bool get autoUseAuthToken;
  int maxEventCount;
  String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  int defaultPageableListPageSize = 20;
}

abstract class ApplicationService<S extends SpongeService> {
  static final Logger _logger = Logger('ApplicationService');

  ConnectionsConfiguration _connectionsConfiguration;
  S _spongeService;
  TypeConverter _typeConverter;
  ApplicationSettings settings;

  ConnectionsConfiguration get connectionsConfiguration =>
      _connectionsConfiguration;
  S get spongeService => _spongeService;

  bool get connected => _spongeService != null && _spongeService.connected;

  bool get logged =>
      connected && _spongeService.client.configuration.username != null;

  Future<void> configure(ConnectionsConfiguration connectionsConfiguration,
      TypeConverter typeConverter) async {
    _connectionsConfiguration = connectionsConfiguration;
    _typeConverter = typeConverter;

    await _connectionsConfiguration.init();
    await _rebuildConnectionsConfiguration();

    try {
      await _setupActiveConnection(
          _connectionsConfiguration.getActiveConnectionName());
    } catch (e) {
      // Only log the error thrown while setting the active connection.
      _logger.severe('Setup active connection error', e, StackTrace.current);
    }
  }

  Future<void> _rebuildConnectionsConfiguration() async {
    var existsDemoService = _connectionsConfiguration.getConnections().any(
        (c) =>
            c.name == ApplicationConstants.DEMO_SERVICE_NAME ||
            c.url == ApplicationConstants.DEMO_SERVICE_ADDRESS);
    if (!existsDemoService) {
      await _connectionsConfiguration.addConnection(SpongeConnection(
          name: ApplicationConstants.DEMO_SERVICE_NAME,
          url: ApplicationConstants.DEMO_SERVICE_ADDRESS,
          anonymous: true));
    }
  }

  Future<void> _setupActiveConnection(String connectionName) async {
    if (connectionName != null) {
      SpongeConnection connection =
          _connectionsConfiguration.getConnection(connectionName);

      SpongeConnection prevConnection = _spongeService?.connection;
      if (connection != null &&
          (prevConnection == null || !connection.isSame(prevConnection))) {
        await closeSpongeService();
        _spongeService = await createSpongeService(connection, _typeConverter);
        await configureSpongeService(_spongeService);
        await _spongeService.open();
        await _connectionsConfiguration.setActiveConnection(connectionName);
        await startSpongeService(_spongeService);
      }
    } else {
      await closeSpongeService();
      _spongeService = null;
    }
  }

  Future<void> closeSpongeService() async {
    // The asynchronous close() is called without await in order not to block the current thread.
    await _spongeService?.close();
    // ?.catchError((e) => _logger.severe('Sponge service closing error', e));
  }

  Future<S> createSpongeService(
          SpongeConnection connection, TypeConverter typeConverter) async =>
      SpongeService(connection, typeConverter: typeConverter) as S;

  Future<void> configureSpongeService(S spongeService) async {
    spongeService.maxEventCount = settings.maxEventCount;
    spongeService.autoUseAuthToken = settings.autoUseAuthToken;
  }

  Future<void> startSpongeService(S spongeService) async {}

  bool isConnectionActive(String connectionName) =>
      _connectionsConfiguration
          .getConnection(_connectionsConfiguration.getActiveConnectionName())
          ?.name ==
      connectionName;

  List<String> getAllConnectionNames() => _connectionsConfiguration
      .getConnections()
      .map((connection) => connection.name)
      .toList();

  bool get hasConnections => _connectionsConfiguration.hasConnections;

  Future<void> setActiveConnection(String connectionName) async {
    await _connectionsConfiguration.setActiveConnection(connectionName);
    await _setupActiveConnection(connectionName);
  }

  Future<void> clearConfiguration() async {
    await _connectionsConfiguration.clearConnections();
    await _rebuildConnectionsConfiguration();
    await setActiveConnection(null);
  }

  Future<void> setConnections(
      List<SpongeConnection> connections, String activeConnectionName) async {
    await _connectionsConfiguration.clearConnections();

    await for (var c in Stream.fromIterable(connections)) {
      await _connectionsConfiguration.addConnection(c);
    }

    await setActiveConnection(activeConnectionName);
  }

  SpongeConnection get activeConnection => _connectionsConfiguration
      .getConnection(_connectionsConfiguration.getActiveConnectionName());

  Future<void> changeActiveConnectionCredentials(
      String username, String password) async {
    var connection = activeConnection;
    connection
      ..username = username
      ..password = password
      ..anonymous = username == null;

    await _connectionsConfiguration.updateConnection(connection);

    _spongeService.connection.setFrom(connection);

    _spongeService.client.configuration
      ..username = connection.username
      ..password = connection.password;

    await _spongeService.client.clearSession();
  }

  Future<void> changeActiveConnectionSubscription(
      List<String> eventNames, bool subscribe) async {
    var connection = activeConnection;
    connection.subscribe = subscribe;
    connection.subscriptionEventNames = eventNames;
    await _connectionsConfiguration.updateConnection(connection);

    _spongeService.connection.setFrom(connection);
  }

  Future<void> clearEventNotifications() async {}
}
