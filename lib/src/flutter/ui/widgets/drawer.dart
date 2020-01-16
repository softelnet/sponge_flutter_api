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
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/routes.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/about_dialog.dart';

class HomeDrawer extends StatelessWidget {
  HomeDrawer({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ApplicationService service = ApplicationProvider.of(context).service;

    final iconColor = getSecondaryColor(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DefaultDrawerHeader(
              applicationName: ApplicationConstants.APPLICATION_NAME),
          ListTile(
            leading: Icon(Icons.directions_run, color: iconColor),
            title: Text('Actions'),
            onTap: () async => showDistinctScreen(context, Routes.ACTIONS),
          ),
          FutureBuilder<bool>(
            future: service.spongeService?.isGrpcEnabled(),
            builder: (context, snapshot) {
              return ListTile(
                leading: Icon(Icons.event, color: iconColor),
                title: Text('Events'),
                enabled: snapshot.hasData && snapshot.data,
                onTap: () async => showDistinctScreen(context, Routes.EVENTS),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.cloud, color: iconColor),
            title: Text('Connections'),
            onTap: () async => showChildScreen(context, Routes.CONNECTIONS),
          ),
          ListTile(
            leading: Icon(Icons.settings, color: iconColor),
            title: Text('Settings'),
            onTap: () async => showChildScreen(context, Routes.SETTINGS),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.info, color: iconColor),
            title: Text('About'),
            onTap: () async => await showAboutAppDialog(context),
          ),
        ],
      ),
    );
  }
}
