// Copyright 2020 The Sponge authors.
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
import 'package:flutter/widgets.dart';
import 'package:sponge_flutter_api/src/common/ui/connections_mvp.dart';

class SpongeWidgetsFactory {
  SpongeWidgetsFactory({
    WidgetBuilder onCreateDrawer,
    OnCreateConnectionsPageMenuItemsCallback onCreateConnectionsPageMenuItems,
    OnCreateRoutesCallback onCreateRoutes,
  })  : _onCreateDrawer = onCreateDrawer,
        _onCreateConnectionsPageMenuItems = onCreateConnectionsPageMenuItems,
        _onCreateRoutes = onCreateRoutes;

  final WidgetBuilder _onCreateDrawer;
  final OnCreateConnectionsPageMenuItemsCallback
      _onCreateConnectionsPageMenuItems;
  final OnCreateRoutesCallback _onCreateRoutes;

  Widget createDrawer(BuildContext context) =>
      _onCreateDrawer != null ? _onCreateDrawer(context) : null;

  List<ConnectionsPageMenuItemConfiguration> createConnectionsPageMenuItems(
          BuildContext context) =>
      _onCreateConnectionsPageMenuItems != null
          ? _onCreateConnectionsPageMenuItems(context)
          : [];

  Map<String, WidgetBuilder> createRoutes() =>
      _onCreateRoutes != null ? _onCreateRoutes() : {};
}

typedef OnCreateConnectionsPageMenuItemsCallback
    = List<ConnectionsPageMenuItemConfiguration> Function(BuildContext context);

typedef OnCreateConnectionsPageMenuItemCallback = PopupMenuEntry<String>
    Function(ConnectionsPresenter connectionsPresenter, BuildContext context);

typedef OnCreateRoutesCallback = Map<String, WidgetBuilder> Function();

class ConnectionsPageMenuItemConfiguration {
  ConnectionsPageMenuItemConfiguration({
    @required this.value,
    @required this.itemBuilder,
    @required this.onSelected,
  });

  final String value;
  final OnCreateConnectionsPageMenuItemCallback itemBuilder;
  final PopupMenuItemSelected<ConnectionsPresenter> onSelected;
}
