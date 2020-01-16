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
import 'package:sponge_flutter_api/src/flutter/routes.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/login_dialog.dart';

class ErrorPanelWidget extends StatelessWidget {
  ErrorPanelWidget({Key key, @required this.error}) : super(key: key);

  final dynamic error;

  @override
  Widget build(BuildContext context) {
    // TODO Verify error is SocketException.
    var isSocketException = error?.runtimeType?.toString() ==
        'SocketException'; //error is SocketException
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(
                Icons.error,
                color: Colors.red,
              ),
              title: Text(isSocketException ? 'Connection error' : 'Error'),
              subtitle: Text('$error'),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorCircleWidget extends StatelessWidget {
  ErrorCircleWidget({Key key, @required this.error}) : super(key: key);

  final dynamic error;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: CircleAvatar(
        child: Icon(Icons.error_outline),
        foregroundColor: Colors.white,
        backgroundColor: Colors.red,
      ),
      onTap: () => showErrorDialog(context, error?.toString() ?? ''),
    );
  }
}

class ConnectionNotInitializedWidget extends StatelessWidget {
  ConnectionNotInitializedWidget({Key key, @required this.hasConnections})
      : super(key: key);

  final bool hasConnections;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Text(hasConnections
            ? 'Please activate a Sponge connection'
            : 'Please tap here to add a new Sponge connection'),
      ),
      onTap: () => Navigator.pushNamed(context, DefaultRoutes.CONNECTIONS),
    );
  }
}

class UsernamePasswordNotSetWidget extends StatelessWidget {
  UsernamePasswordNotSetWidget({Key key, @required this.connectionName})
      : super(key: key);

  final String connectionName;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Text('Please tap here to login to $connectionName'),
      ),
      onTap: () async => await showLoginPage(context, connectionName),
    );
  }
}
