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

import 'dart:convert';

import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';

abstract class ConnectionsConfiguration {
  Future<void> init();

  String getActiveConnectionName();

  List<SpongeConnection> getConnections();

  SpongeConnection getConnection(String connectionName);

  Future<void> addConnection(SpongeConnection connection);

  Future<void> updateConnection(SpongeConnection connection);

  Future<void> setActiveConnection(String connectionName);

  Future<void> clearConnections();

  bool get hasConnections => getConnections().isNotEmpty;
}

class BaseConnectionsConfiguration implements ConnectionsConfiguration {
  final Map<String, SpongeConnection> _connections = Map();
  String _activeConnectionName;

  @override
  Future<void> init() async {}

  @override
  Future<void> addConnection(SpongeConnection connection) async {
    _connections[connection.name] = connection;
  }

  Future<void> updateConnection(SpongeConnection connection) async {
    _connections[connection.name].setFrom(connection);
  }

  @override
  Future<void> clearConnections() async => _connections.clear();

  @override
  String getActiveConnectionName() => _activeConnectionName;

  @override
  SpongeConnection getConnection(String connectionName) =>
      _connections[connectionName];

  @override
  List<SpongeConnection> getConnections() => _connections.values.toList();

  @override
  bool get hasConnections => _connections.isNotEmpty;

  @override
  Future<void> setActiveConnection(String connectionName) async {
    _activeConnectionName = connectionName;
  }

  String encode(String plainText) =>
      plainText != null ? base64.encode(utf8.encode(plainText)) : null;

  String decode(String encodedText) =>
      encodedText != null ? utf8.decode(base64.decode(encodedText)) : null;
}
