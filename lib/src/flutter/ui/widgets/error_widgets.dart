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
import 'package:sponge_flutter_api/sponge_flutter_api.dart';
import 'package:sponge_flutter_api/src/common/util/common_utils.dart';
import 'package:sponge_flutter_api/src/flutter/default_routes.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';

enum NotificationPanelType { error, info }

class NotificationPanelWidget extends StatelessWidget {
  NotificationPanelWidget({
    Key key,
    @required dynamic notification,
    @required NotificationPanelType type,
  })  : _notification = notification,
        _type = type,
        super(key: key);

  final dynamic _notification;
  final NotificationPanelType _type;

  @override
  Widget build(BuildContext context) {
    String title;
    IconData icon;
    Color color;
    switch (_type) {
      case NotificationPanelType.error:
        title = CommonUtils.isNetworkError(_notification)
            ? 'Connection error'
            : 'Error';
        icon = Icons.error;
        color = Colors.red;
        break;
      case NotificationPanelType.info:
        title = 'Information';
        icon = Icons.info;
        color = Colors.blue;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        child: ListTile(
          leading: Icon(
            icon,
            color: color,
          ),
          title: Text(title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('$_notification'),
          ),
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
    return InkResponse(
      child: CircleAvatar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.red,
        child: const Icon(Icons.error_outline),
      ),
      onTap: () => showErrorDialog(context, error?.toString() ?? ''),
    );
  }
}

TextStyle getTapHereMessageStyle(BuildContext context) =>
    Theme.of(context).textTheme.subtitle1;

class ConnectionNotInitializedWidget extends StatelessWidget {
  ConnectionNotInitializedWidget({Key key, @required this.hasConnections})
      : super(key: key);

  final bool hasConnections;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(10),
        child: Text(
          hasConnections
              ? 'Please tap here to activate\na Sponge connection'
              : 'Please tap here to add \na new Sponge connection',
          key: Key('tapToActivateConnection'),
          style: getTapHereMessageStyle(context),
          textAlign: TextAlign.center,
        ),
      ),
      onTap: () => Navigator.pushNamed(context, DefaultRoutes.CONNECTIONS),
    );
  }
}

class LoginRequiredWidget extends StatelessWidget {
  LoginRequiredWidget({Key key, @required this.connectionName})
      : super(key: key);

  final String connectionName;

  @override
  Widget build(BuildContext context) {
    var service = ApplicationProvider.of(context).service;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(10),
        child: Text(
          'Please tap here to login to\n$connectionName',
          key: Key('tapToLogin'),
          style: getTapHereMessageStyle(context),
          textAlign: TextAlign.center,
        ),
      ),
      onTap: () => service.showLoginPage(context, connectionName),
    );
  }
}
