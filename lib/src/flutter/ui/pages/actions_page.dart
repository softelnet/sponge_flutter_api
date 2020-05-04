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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:modal_progress_hud/modal_progress_hud.dart';
import 'package:provider/provider.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/sponge_flutter_api.dart';
import 'package:sponge_flutter_api/src/common/bloc/connection_state.dart';
import 'package:sponge_flutter_api/src/common/ui/pages/actions_mvp.dart';
import 'package:sponge_flutter_api/src/external/async_popup_menu_button.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/pages/action_call_page.dart';
import 'package:sponge_flutter_api/src/flutter/ui/pages/action_list_item_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/error_widgets.dart';

class ActionsPage extends StatefulWidget {
  ActionsPage({
    Key key,
    this.onGetNetworkStatus,
  }) : super(key: key);

  final AsyncValueGetter<NetworkStatus> onGetNetworkStatus;

  @override
  _ActionsPageState createState() => _ActionsPageState();
}

class _ActionGroup {
  _ActionGroup(this.name, this.actions);

  final String name;
  final List<ActionData> actions;
}

class _ActionsPageState extends State<ActionsPage>
    with TickerProviderStateMixin
    implements ActionsView {
  ActionsPresenter _presenter;
  int _initialTabIndex = 0;
  bool _useTabs;
  bool _busyNoConnection = false;

  String _lastConnectionName;

  Future<List<_ActionGroup>> _getActionGroups() async {
    var allActions = await _presenter.getActions();

    var groupMap = <String, List<ActionData>>{};
    allActions.forEach((action) =>
        (groupMap[ModelUtils.getActionGroupDisplayLabel(action.actionMeta)] ??=
                [])
            .add(action));

    var actionGroups = groupMap.entries
        .map((entry) => _ActionGroup(entry.key, entry.value))
        .toList();
    return actionGroups;
  }

  bool _isDone(AsyncSnapshot<List<_ActionGroup>> snapshot) =>
      snapshot.connectionState == ConnectionState.done && snapshot.hasData;

  @override
  Widget build(BuildContext context) {
    var service = ApplicationProvider.of(context).service;
    _presenter ??= ActionsPresenter(service, this);
    service.bindMainBuildContext(context);

    return WillPopScope(
      child: BlocBuilder<ForwardingBloc<SpongeConnectionState>,
              SpongeConnectionState>(
          bloc: service.connectionBloc,
          builder: (BuildContext context, SpongeConnectionState state) {
            if (state is SpongeConnectionStateNotConnected) {
              return _buildScaffold(
                context,
                child: ConnectionNotInitializedWidget(
                    hasConnections: _presenter.hasConnections),
              );
            } else if (state is SpongeConnectionStateConnecting) {
              return _buildScaffold(
                context,
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (state is SpongeConnectionStateError) {
              return _buildScaffold(
                context,
                child: Center(
                  child: _buildErrorWidget(state.error),
                ),
              );
            } else {
              return _buildMainWidget(context);
            }
          }),
      onWillPop: () async => await showAppExitConfirmationDialog(context),
    );
  }

  Widget _buildMainWidget(BuildContext context) {
    return FutureBuilder<List<_ActionGroup>>(
      future: _busyNoConnection ? Future(() => []) : _getActionGroups(),
      builder: (context, snapshot) {
        _useTabs = FlutterApplicationService.of(_presenter.service)
                .settings
                .tabsInActionList &&
            _isDone(snapshot) &&
            snapshot.data.length > 1;

        _lastConnectionName ??= _presenter.connectionName;
        if (_useTabs) {
          if (_lastConnectionName != _presenter.connectionName) {
            _initialTabIndex = 0;
          } else {
            _initialTabIndex =
                _useTabs && _initialTabIndex < snapshot.data.length
                    ? _initialTabIndex
                    : 0;
          }
        }

        if (!_useTabs && _isDone(snapshot)) {
          _initialTabIndex = 0;
        }

        _lastConnectionName = _presenter.connectionName;

        var tabBar = _useTabs
            ? TabBar(
                // TODO Parametrize the tabbar scroll in settings.
                isScrollable: snapshot.data.length > 3,
                tabs: snapshot.data
                    .map(
                      (group) => Tab(
                        key: Key('group-${group.name}'),
                        child: Tooltip(
                          child: Text(group.name.toUpperCase()),
                          message: group.name,
                        ),
                      ),
                    )
                    .toList(),
                onTap: (index) => _initialTabIndex = index,
                indicatorColor: getSecondaryColor(context),
              )
            : null;

        var scaffold = _buildScaffold(
          context,
          child: _presenter.connected
              ? (_busyNoConnection
                  ? Center(child: CircularProgressIndicator())
                  : _buildActionGroupWidget(context, snapshot))
              : ConnectionNotInitializedWidget(
                  hasConnections: _presenter.hasConnections),
          tabBar: tabBar,
          actionGroupsSnapshot: snapshot,
        );

        return _useTabs
            ? DefaultTabController(
                length: snapshot.data.length,
                child: scaffold,
                initialIndex: _initialTabIndex,
              )
            : scaffold;
      },
    );
  }

  Scaffold _buildScaffold(
    BuildContext context, {
    @required Widget child,
    PreferredSizeWidget tabBar,
    AsyncSnapshot<List<_ActionGroup>> actionGroupsSnapshot =
        const AsyncSnapshot.withData(ConnectionState.done, []),
  }) {
    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(context),
        actions: _buildConnectionsWidget(context),
        bottom: tabBar,
      ),
      drawer: Provider.of<SpongeGuiFactory>(context).createDrawer(context),
      body: SafeArea(
        child: ModalProgressHUD(
          child: child,
          inAsyncCall: _presenter.busy,
        ),
      ),
      floatingActionButton: _presenter.service.connectionBloc.state
              is SpongeConnectionStateNotConnected
          ? null
          : _buildFloatingActionButton(
              context,
            ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget _buildActionGroupWidget(
      BuildContext context, AsyncSnapshot<List<_ActionGroup>> snapshot) {
    //if (_isDone(snapshot)) {
    //if (snapshot.data.length > 1) {

    bool showSimpleActionName =
        _useTabs || snapshot.hasData && snapshot.data.length == 1;

    if (_useTabs) {
      return TabBarView(
        children: snapshot.data
            .map((group) => Center(
                child: _buildActionListWidget(context, 'actions-${group.name}',
                    snapshot, group.actions, !showSimpleActionName)))
            .toList(),
      );
    } else {
      return Center(
        child: _buildActionListWidget(
            context,
            'actions',
            snapshot,
            snapshot.data != null
                ? snapshot.data.expand((group) => group.actions).toList()
                : [],
            !showSimpleActionName),
      );
    }
  }

  Widget _buildTitle(BuildContext context) {
    return Tooltip(
      child: Text(
        _presenter.connectionName != null
            ? '${_presenter.connectionName}'
            : 'Actions',
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
      message: _presenter.connectionName != null
          ? '${_presenter.connectionName} actions'
          : 'Actions',
    );
  }

  Future<void> _changeConnection(BuildContext context, String name) async {
    try {
      setState(() {
        _presenter.busy = _busyNoConnection = true;
      });

      try {
        await _presenter.onConnectionChange(name);
      } finally {
        // Concurrent connection change is allowed. Prevents a stale connection to be shown in the GUI.
        if (mounted && _busyNoConnection && name == _presenter.connectionName) {
          setState(() {
            _presenter.busy = _busyNoConnection = false;
            //if (isNewConnectionDifferent) {
            _initialTabIndex = 0;
            //}
          });
        }
      }
    } catch (e) {
      // Concurrent connection change is allowed. Prevents a stale connection to be shown in the GUI.
      if (mounted && _busyNoConnection && name == _presenter.connectionName) {
        await handleError(context, e);
      }
    }
  }

  List<Widget> _buildConnectionsWidget(BuildContext context) {
    if (!_presenter.hasConnections) {
      return null;
    }

    var service = FlutterApplicationService.of(_presenter.service);

    return <Widget>[
      AsyncPopupMenuButton<String>(
        key: Key('connections'),
        onSelected: (value) async {
          if (value.startsWith('connection-')) {
            await _changeConnection(
                context, value.substring('connection-'.length));
          } else if (value == 'filterByNetwork') {
            await service.settings.setFilterConnectionsByNetwork(
                !service.settings.filterConnectionsByNetwork);
          }
        },
        itemBuilder: (BuildContext context) async {
          var connections = _presenter.getConnections(
              widget.onGetNetworkStatus != null &&
                  service.settings.filterConnectionsByNetwork,
              widget.onGetNetworkStatus != null
                  ? await widget.onGetNetworkStatus()
                  : null);
          return [
            if (widget.onGetNetworkStatus != null)
              CheckedPopupMenuItem<String>(
                key: Key('filterByNetwork'),
                value: 'filterByNetwork',
                checked: service.settings.filterConnectionsByNetwork,
                child: Text('Filter by network'),
              ),
            if (widget.onGetNetworkStatus != null && connections.isNotEmpty)
              PopupMenuDivider(),
            ...connections
                .map(
                  (c) => CheckedPopupMenuItem<String>(
                    key: Key('connection-${c.name}'),
                    value: 'connection-${c.name}',
                    checked: c.isActive,
                    child: Text(c.name),
                  ),
                )
                .toList(),
          ];
        },
        padding: EdgeInsets.zero,
      )
    ];
  }

  Widget _buildFloatingActionButton(BuildContext context) =>
      FloatingActionButton(
        onPressed: () => _refreshActions(context)
            .then((_) => setState(() {}))
            .catchError((e) => handleError(context, e)),
        tooltip: 'Refresh actions',
        child: Icon(Icons.refresh),
      );

  Future<void> _refreshActions(BuildContext context) async {
    await _presenter.refreshActions();
    ApplicationProvider.of(context)
        .updateConnection(_presenter.connection, force: true);
  }

  Widget _buildActionListWidget(
      BuildContext context,
      String tabName,
      AsyncSnapshot<List<_ActionGroup>> snapshot,
      List<ActionData> actions,
      bool showQualifiedActionName) {
    if (snapshot.connectionState == ConnectionState.done) {
      if (snapshot.hasData) {
        return ListView.builder(
          key: PageStorageKey<String>(
              '${_presenter.connectionName}-actions-$tabName'),
          padding: const EdgeInsets.only(
              left: 4.0, right: 4.0, top: 4.0, bottom: 100.0),
          itemBuilder: (context, i) {
            var actionData = actions[i];
            return ActionListItem(
              key: Key('action-${actionData.actionMeta.name}'),
              actionData: actionData,
              onActionCall: (action) async {
                if (_useTabs) {
                  _initialTabIndex =
                      DefaultTabController.of(context)?.index ?? 0;
                }
                await _presenter.onActionCall(action);
              },
              showQualifiedName: showQualifiedActionName,
            );
          },
          itemCount: actions.length,
        );
      } else if (snapshot.hasError) {
        return _buildErrorWidget(snapshot.error);
      }
    }

    // By default, show a loading spinner.
    return CircularProgressIndicator();
  }

  Widget _buildErrorWidget(dynamic error) {
    if (error is UsernamePasswordNotSetException ||
        error is InvalidUsernamePasswordException) {
      return LoginRequiredWidget(connectionName: _presenter.connectionName);
    } else {
      return NotificationPanelWidget(
        notification: error,
        type: NotificationPanelType.error,
      );
    }
  }

  @override
  Future<bool> showActionCallConfirmationDialog(ActionData actionData) async =>
      await showConfirmationDialog(context,
          'Do you want to run ${ModelUtils.getActionMetaDisplayLabel(actionData.actionMeta)}?');

  @override
  Future<ActionData> showActionCallScreen(ActionData actionData) async {
    return await showActionCall(
      context,
      actionData,
      builder: (context) => ActionCallPage(
        actionData: actionData,
        bloc: _presenter.service.spongeService
            .getActionCallBloc(actionData.actionMeta.name),
      ),
    );
  }
}
