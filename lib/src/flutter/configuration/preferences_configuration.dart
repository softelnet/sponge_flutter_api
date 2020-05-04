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

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/configuration/connections_configuration.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';

class SharedPreferencesConnectionsConfiguration
    extends ConnectionsConfiguration {
  SharedPreferencesConnectionsConfiguration(this._prefs);

  static const _KEY_ACTIVE_CONNECTION = 'activeConnection';
  static const _KEY_CONNECTIONS = 'connections';
  static const _KEY_PREFIX = 'connections.connection.';

  final SharedPreferences _prefs;
  final _baseConfiguration = BaseConnectionsConfiguration();

  @override
  Future<void> init() async {
    await _baseConfiguration
        .setActiveConnection(_prefs.getString(_KEY_ACTIVE_CONNECTION));
    _readConnections().forEach((connection) async =>
        await _baseConfiguration.addConnection(connection));
  }

  @override
  Future<void> setActiveConnection(String connectionName) async {
    if (connectionName != null) {
      await _prefs.setString(_KEY_ACTIVE_CONNECTION, connectionName);
    } else {
      await _prefs.remove(_KEY_ACTIVE_CONNECTION);
    }

    await _baseConfiguration.setActiveConnection(connectionName);
  }

  @override
  String getActiveConnectionName() =>
      _baseConfiguration.getActiveConnectionName();

  @override
  List<SpongeConnection> getConnections() =>
      _baseConfiguration.getConnections();

  List<SpongeConnection> _readConnections() {
    List<SpongeConnection> connections =
        (_prefs.getStringList(_KEY_CONNECTIONS) ?? [])
            .map((name) => _readConnection(name))
            .where((connection) => connection != null)
            .toList();
    connections.sort();

    return connections;
  }

  @override
  SpongeConnection getConnection(String connectionName) =>
      _baseConfiguration.getConnection(connectionName);

  @override
  Future<void> addConnection(SpongeConnection connection) async {
    List<String> connectionNameList =
        _prefs.getStringList(_KEY_CONNECTIONS) ?? [];
    Validate.isTrue(!connectionNameList.any((name) => name == connection.name),
        'Connection ${connection.name} already exists');

    connectionNameList.add(connection.name);

    await _prefs.setStringList(_KEY_CONNECTIONS, connectionNameList);

    await _saveConnection(connection);

    await _baseConfiguration.addConnection(connection);
  }

  @override
  Future<void> updateConnection(SpongeConnection connection) async {
    await _saveConnection(connection);

    await _baseConfiguration.updateConnection(connection);
  }

  Future<void> _saveConnection(SpongeConnection connection) async {
    await _prefs.setString(
        '$_KEY_PREFIX${connection.name}.url', connection.url);

    var username = connection.username;
    var password = connection.password;

    if (!connection.savePassword) {
      password = null;
    }

    await _prefs.setString('$_KEY_PREFIX${connection.name}.username', username);
    await _prefs.setString('$_KEY_PREFIX${connection.name}.password',
        _baseConfiguration.encode(password));
    await _prefs.setBool(
        '$_KEY_PREFIX${connection.name}.anonymous', connection.anonymous);
    await _prefs.setBool(
        '$_KEY_PREFIX${connection.name}.savePassword', connection.savePassword);
    await _prefs.setString(
        '$_KEY_PREFIX${connection.name}.network', connection.network);
    await _prefs.setBool(
        '$_KEY_PREFIX${connection.name}.subscribe', connection.subscribe);
    await _prefs.setStringList('$_KEY_PREFIX${connection.name}.subscription',
        connection.subscriptionEventNames);
  }

  SpongeConnection _readConnection(String name) {
    return SpongeConnection(
      name: name,
      url: _prefs.getString('$_KEY_PREFIX$name.url'),
      username: _prefs.getString('$_KEY_PREFIX$name.username'),
      password: _baseConfiguration
          .decode(_prefs.getString('$_KEY_PREFIX$name.password')),
      anonymous: _prefs.getBool('$_KEY_PREFIX$name.anonymous'),
      savePassword: _prefs.getBool('$_KEY_PREFIX$name.savePassword'),
      network: _prefs.getString('$_KEY_PREFIX$name.network'),
      subscribe: _prefs.getBool('$_KEY_PREFIX$name.subscribe'),
      subscriptionEventNames:
          _prefs.getStringList('$_KEY_PREFIX$name.subscription'),
    );
  }

  void removeConnection(SpongeConnection connection) async {
    await _prefs.remove('$_KEY_PREFIX${connection.name}.url');
    await _prefs.remove('$_KEY_PREFIX${connection.name}.username');
    await _prefs.remove('$_KEY_PREFIX${connection.name}.password');
    await _prefs.remove('$_KEY_PREFIX${connection.name}.anonymous');
    await _prefs.remove('$_KEY_PREFIX${connection.name}.savePassword');
    await _prefs.remove('$_KEY_PREFIX${connection.name}.network');
    await _prefs.remove('$_KEY_PREFIX${connection.name}.subscribe');
    await _prefs.remove('$_KEY_PREFIX${connection.name}.subscription');
  }

  @override
  Future<void> clearConnections() async {
    await _prefs.remove(_KEY_ACTIVE_CONNECTION);
    await _prefs.remove(_KEY_CONNECTIONS);
    await _clearAllConnections();

    await _baseConfiguration.clearConnections();
  }

  Future<void> _clearAllConnections() async {
    for (var key in _prefs
        .getKeys()
        .where((key) => key.startsWith(_KEY_PREFIX))
        .toList()) {
      await _prefs.remove(key);
    }
  }
}
