// Copyright 2019 The Sponge authors.
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
import 'package:pedantic/pedantic.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/ui/events_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/state_container.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/action_call.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/drawer.dart';

class EventsWidget extends StatefulWidget {
  EventsWidget({Key key}) : super(key: key);

  @override
  _EventsWidgetState createState() => _EventsWidgetState();
}

class _EventsWidgetState extends State<EventsWidget>
    with SingleTickerProviderStateMixin
    implements EventsView {
  static const String DISMISS_ALL = 'dismissAll';

  EventsPresenter _presenter;
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: const Duration(seconds: 4), vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var service = StateContainer.of(context).service;
    _presenter ??= EventsPresenter(this);
    this._presenter.setService(service);

    service.bindMainBuildContext(context);

    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: _buildTitle(context),
          actions: _buildActionsWidget(context),
        ),
        drawer: HomeDrawer(),
        body: SafeArea(
          child: _presenter.bloc != null
              ? StreamBuilder<EventData>(
                  stream: _presenter.bloc.event,
                  builder: (BuildContext context,
                          AsyncSnapshot<EventData> snapshot) =>
                      _buildEventList(),
                )
              : Container(),
        ),
        // floatingActionButton: FloatingActionButton(
        //   onPressed: () => setState(() {}),
        //   tooltip: 'Refresh events',
        //   child: Icon(Icons.refresh),
        //   backgroundColor: UiUtils.getFloatingButtonBackgroudColor(context),
        // ),
      ),
      onWillPop: () async => await showAppExitConfirmationDialog(context),
    );
  }

  Widget _buildEventList() {
    var events = _presenter.getEvents();

    unawaited(_presenter.clearEventNotifications());

    return ListView.builder(
      key: Key('eventList'),
      itemBuilder: (context, i) {
        var eventData = events[i];
        return Dismissible(
          key: Key(eventData.event.id),
          child: Card(
            key: Key('event-$i'),
            child: ListTile(
              // leading: // TODO event icon from type or default. _presenter.isConnectionActive(connection.name)
              //     ? Icon(
              //         Icons.check,
              //         color: Theme.of(context).primaryColor,
              //       )
              //     : null,
              trailing: GestureDetector(
                child: Icon(Icons.delete_sweep),
                onTap: () => _removeEvent(context, eventData.event.id),
              ),
              title: Text(_presenter.getEventLabel(eventData)),
              onTap: () => _showEventDetails(context, eventData)
                  .catchError((e) => handleError(context, e)),
            ),
          ),
          onDismissed: (direction) => _removeEvent(context, eventData.event.id),
        );
      },
      itemCount: events.length,
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text('Events' +
        (_presenter.connectionName != null
            ? ' (${_presenter.connectionName})'
            : ''));
  }

  List<Widget> _buildActionsWidget(BuildContext context) {
    var icon = Icon(Icons.explore);

    return <Widget>[
      // TODO Create a new widget.
      _presenter.subscriptionBloc != null
          ? StreamBuilder<bool>(
              stream: _presenter.subscriptionBloc,
              initialData: false,
              builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                if (snapshot.data) {
                  _controller.repeat();
                } else {
                  _controller.stop(canceled: false);
                }

                return GestureDetector(
                  child: SpinningWidget(
                    controller: _controller,
                    child: icon,
                  ),
                  onTap: () async => await _onSubscriptionStatus(context),
                );
              },
            )
          : icon,
      PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case DISMISS_ALL:
              _presenter.dismissAll();
              setState(() {});
              break;
          }
        },
        itemBuilder: (BuildContext context) => [
          PopupMenuItem<String>(
            value: DISMISS_ALL,
            child: Text('Dismiss all'),
          ),
        ],
      )
    ];
  }

  Future<void> _showEventDetails(
      BuildContext context, EventData eventData) async {
    await showEventHandlerAction(context, eventData);
  }

  Future<void> _removeEvent(BuildContext context, String eventId) async {
    try {
      await _presenter.removeEvent(eventId);
    } catch (e) {
      await handleError(context, e);
    }

    setState(() {});
  }

  Future<void> _onSubscriptionStatus(BuildContext context) async {
    ActionData subscriptionActionData =
        await _presenter.service.spongeService.findSubscriptionAction();

    if (subscriptionActionData != null) {
      var resultActionData = await showActionCall(
        context,
        subscriptionActionData,
        builder: (context) => ActionCallWidget(
          actionData: subscriptionActionData,
          bloc: _presenter.service.spongeService
              .getActionCallBloc(subscriptionActionData.actionMeta.name),
          callImmediately: true,
          showResultDialogIfNoResult: false,
        ),
      );

      if (resultActionData != null) {
        setState(() {});
      }
    }
  }
}