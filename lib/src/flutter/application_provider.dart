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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';

class ApplicationProvider extends StatefulWidget {
  ApplicationProvider({
    @required this.child,
    @required this.service,
  });

  final Widget child;
  final FlutterApplicationService service;

  static ApplicationProviderState of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_InheritedStateContainer>()
      .data;

  @override
  ApplicationProviderState createState() => ApplicationProviderState();
}

class ApplicationProviderState extends State<ApplicationProvider> {
  SpongeConnection _connection;
  FlutterApplicationService get service => widget.service;
  PageStorageBucket _bucket;
  PageStorageBucket get bucket => _bucket;
  PageStorageKey _storageKey;
  PageStorageKey get storageKey => _storageKey;

  bool updateConnection(
    SpongeConnection connection, {
    bool refresh = true,
    bool force = false,
  }) {
    if (_connection == null || !_connection.isSame(connection) || force) {
      // Recreate PageStorage after connection change.
      _createPageStorage();

      if (refresh) {
        setState(() {
          _connection = SpongeConnection.of(connection);
        });
      } else {
        _connection = SpongeConnection.of(connection);
      }

      return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();

    _connection = widget.service?.activeConnection;

    _createPageStorage();
  }

  void _createPageStorage() {
    _bucket = PageStorageBucket();
    _storageKey = PageStorageKey('application-provider-${_connection?.name}');
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedStateContainer(
      data: this,
      child: ChangeNotifierProvider<ApplicationStateNotifier>(
        create: (_) => widget.service.stateNotifier,
        child: PageStorage(
          bucket: _bucket,
          key: _storageKey,
          child: widget.child,
        ),
      ),
    );
  }
}

class _InheritedStateContainer extends InheritedWidget {
  _InheritedStateContainer({
    Key key,
    @required this.data,
    @required Widget child,
  }) : super(key: key, child: child);

  final ApplicationProviderState data;

  @override
  bool updateShouldNotify(_InheritedStateContainer old) => true;
}
