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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pedantic/pedantic.dart';
import 'package:provider/provider.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/forwarding_bloc.dart';
import 'package:sponge_flutter_api/src/common/ui/pages/events_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/gui_factory.dart';
import 'package:sponge_flutter_api/src/flutter/ui/pages/action_call_page.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/action_call_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/model_gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/widgets.dart';

class EventsPage extends StatefulWidget {
  EventsPage({Key key}) : super(key: key);

  @override
  _EventsPageState createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage>
    with SingleTickerProviderStateMixin
    implements EventsView {
  static const String DISMISS_ALL = 'dismissAll';
  static const String CLEAR_SYSTEM_NOTIFICATIONS = 'clearSystemNotifications';

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
    var service = ApplicationProvider.of(context).service;

    _presenter ??= EventsPresenter(service, this);

    service.bindMainBuildContext(context);

    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: _buildTitle(context),
          actions: _buildActionsWidget(context),
        ),
        drawer: Provider.of<SpongeGuiFactory>(context).createDrawer(context),
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
      ),
      onWillPop: () async => await showAppExitConfirmationDialog(context),
    );
  }

  Widget _buildEventList() {
    var events = _presenter.getEvents();

    return ListView.builder(
      key: Key('eventList'),
      itemBuilder: (context, i) {
        var eventData = events[i];
        return Dismissible(
          key: Key(eventData.event.id),
          child: Card(
            key: Key('event-$i'),
            child: ListTile(
              leading: getIcon(
                    context,
                    _presenter.service,
                    Features.getIcon(eventData.event?.features) ??
                        Features.getIcon(eventData.type?.features),
                  ) ??
                  Icon(
                    Icons.event,
                    color: Theme.of(context).primaryColor,
                  ),
              trailing: InkResponse(
                child: const Icon(Icons.delete_sweep),
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
    return Tooltip(
      message: _presenter.connectionName != null
          ? '${_presenter.connectionName} events'
          : 'Events',
      child: Text(
        _presenter.connectionName != null
            ? '${_presenter.connectionName} (Events)'
            : 'Events',
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
    );
  }

  List<Widget> _buildActionsWidget(BuildContext context) {
    var icon = const Icon(Icons.explore);

    return <Widget>[
      _presenter.subscriptionBloc != null
          ? BlocBuilder<ForwardingBloc<bool>, bool>(
              bloc: _presenter.subscriptionBloc,
              builder: (BuildContext context, bool state) {
                if (state) {
                  _controller.repeat();
                } else {
                  _controller.stop(canceled: false);
                }

                return InkResponse(
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
            case CLEAR_SYSTEM_NOTIFICATIONS:
              unawaited(_presenter.clearEventNotifications());
              break;
          }
        },
        itemBuilder: (BuildContext context) => [
          PopupMenuItem<String>(
            value: DISMISS_ALL,
            child: IconTextPopupMenuItemWidget(
              icon: Icons.clear_all,
              text: 'Dismiss all events',
            ),
          ),
          PopupMenuItem<String>(
            value: CLEAR_SYSTEM_NOTIFICATIONS,
            child: IconTextPopupMenuItemWidget(
              icon: Icons.notifications_off,
              text: 'Clear system notifications',
            ),
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
        builder: (context) => ActionCallPage(
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
    } else {
      await showWarningDialog(
          context, 'An event subscription action not found.');
    }
  }
}
