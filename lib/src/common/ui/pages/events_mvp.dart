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

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/event_received_bloc.dart';
import 'package:sponge_flutter_api/src/common/bloc/forwarding_bloc.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';

class EventsViewModel extends BaseViewModel {}

abstract class EventsView extends BaseView {}

class EventsPresenter extends BasePresenter<EventsViewModel, EventsView> {
  EventsPresenter(ApplicationService service, EventsView view) : super(service, EventsViewModel(), view);

  static final Logger _logger = Logger('EventsPresenter');

  EventReceivedBloc get bloc => service.spongeService.eventReceivedBloc;

  ForwardingBloc<bool> get subscriptionBloc =>
      service.spongeService.subscriptionBloc;

  String get connectionName => service.spongeService?.connection?.name;

  bool get isSubscribed => service.spongeService?.isSubscribed ?? false;

  List<EventData> getEvents() {
    // Create a new copy of the list.
    return service.spongeService.events.toList(growable: false);
  }

  Future<void> removeEvent(String eventId) async =>
      service.spongeService.removeEvent(eventId);

  String getEventLabel(EventData eventData) =>
      '[${DateFormat(service.settings.dateTimeFormat).format(eventData.event.time)}]  ${eventData.event.label ?? eventData.type?.label ?? eventData.event.name}';

  Future<void> clearEventNotifications() async => service
      .clearEventNotifications()
      .catchError((e) => _logger.severe('Clear event notifications error: $e'));

  void dismissAll() => service.spongeService.clearEvents();
}
