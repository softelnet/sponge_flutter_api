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
import 'package:modal_progress_hud/modal_progress_hud.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/ui/connections_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/connection_edit.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';

class ConnectionsPage extends StatefulWidget {
  ConnectionsPage({Key key}) : super(key: key);

  @override
  createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage>
    implements ConnectionsView {
  ConnectionsPresenter _presenter;

  @override
  void initState() {
    super.initState();

    _presenter = ConnectionsPresenter(ConnectionsViewModel(), this);
  }

  @override
  Widget build(BuildContext context) {
    _presenter
      ..setService(ApplicationProvider.of(context).service)
      ..refreshModel();

    return Scaffold(
      appBar: AppBar(
        title: Text('Connections'),
        actions: _buildMenu(context),
      ),
      body: SafeArea(
        child: ModalProgressHUD(
          child: _buildWidget(),
          inAsyncCall: _presenter.busy,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _addConnection().catchError((e) => handleError(context, e)),
        tooltip: 'Add',
        child: Icon(Icons.add),
        backgroundColor: getFloatingButtonBackgroudColor(context),
      ),
    );
  }

  Widget _buildWidget() {
    return Builder(
      // Create an inner BuildContext so that the other methods
      // can refer to the Scaffold with Scaffold.of().
      builder: (BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(4.0),
        itemBuilder: (context, i) => _buildRow(context, i),
        itemCount: _presenter.connections.length,
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    SpongeConnection connection = _presenter.connections[index];

    return Dismissible(
      key: Key(connection.name),
      child: Card(
        child: ListTile(
          leading: _presenter.isConnectionActive(connection.name)
              ? Icon(
                  Icons.check,
                  color: getIconColor(context),
                )
              : null,
          trailing: GestureDetector(
            child: Icon(Icons.edit, color: getIconColor(context)),
            onTap: () => _editConnection(context, connection)
                .catchError((e) => handleError(context, e)),
          ),
          title: Text(connection.name),
          onTap: () => _toggleActiveConnection(connection)
              .catchError((e) => handleError(context, e)),
        ),
      ),
      onDismissed: (direction) => _removeConnection(context, index)
          .catchError((e) => handleError(context, e)),
    );
  }

  List<Widget> _buildMenu(BuildContext context) => <Widget>[
        PopupMenuButton<String>(
          key: Key('connections-menu'),
          onSelected: (value) async {
            switch (value) {
              case 'updateDefaultConnections':
                await _presenter.service.updateDefaultConnections();
                setState(() {});

                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              key: Key('updateDefaultConnections'),
              value: 'updateDefaultConnections',
              child: Text('Update default connections'),
            )
          ],
          padding: EdgeInsets.zero,
        )
      ];

  _toggleActiveConnection(SpongeConnection connection) async {
    setState(() {
      _presenter.busy = true;
    });

    try {
      await _presenter.toggleActiveConnection(connection);

      ApplicationProvider.of(context).updateConnection(connection);
    } finally {
      setState(() {
        _presenter.busy = false;
      });
    }
  }

  _addConnection() async {
    setState(() {
      _presenter.busy = true;
    });

    try {
      await _presenter.addConnection();
    } finally {
      setState(() {
        _presenter.busy = false;
      });
    }
  }

  _editConnection(
      BuildContext context, SpongeConnection editedConnection) async {
    var newConnection = await _presenter.editConnection(editedConnection);

    if (newConnection != null) {
      ApplicationProvider.of(context).updateConnection(newConnection);
    }

    setState(() {});
  }

  _removeConnection(BuildContext context, int index) async {
    var removedConnection = await _presenter.removeConnection(index);

    setState(() {});

    var backgroundColor = getSecondaryColor(context);

    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text(
        'Connection ${removedConnection?.name} removed',
        style: TextStyle(color: getContrastColor(backgroundColor)),
      ),
      backgroundColor: backgroundColor,
    ));
  }

  Future<SpongeConnection> addConnection() async => await Navigator.push(
        context,
        MaterialPageRoute<SpongeConnection>(
          builder: (context) => ConnectionEditPage(),
        ),
      );

  Future<SpongeConnection> editConnection(SpongeConnection connection) async {
    return await Navigator.push(
      context,
      MaterialPageRoute<SpongeConnection>(
        builder: (context) =>
            ConnectionEditPage(originalConnection: connection),
      ),
    );
  }
}
