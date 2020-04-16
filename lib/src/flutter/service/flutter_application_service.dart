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

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';
import 'package:sponge_flutter_api/src/common/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/compatibility/feature_converter.dart';
import 'package:sponge_flutter_api/src/flutter/compatibility/type_converter.dart';
import 'package:sponge_flutter_api/src/flutter/configuration/preferences_configuration.dart';
import 'package:sponge_flutter_api/src/flutter/model/flutter_model.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_settings.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/default_type_gui_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';

class ApplicationStateNotifier extends ChangeNotifier {
  ApplicationStateNotifier(this.service);

  final FlutterApplicationService service;

  void notify() {
    notifyListeners();
  }
}

class FlutterApplicationService<S extends FlutterSpongeService,
    T extends FlutterApplicationSettings> extends ApplicationService<S, T> {
  FlutterApplicationService();

  static final Logger _logger = Logger('FlutterApplicationService');
  SharedPreferences _prefs;
  DefaultTypeGuiProviderRegistry typeGuiProviderRegistry =
      DefaultTypeGuiProviderRegistry();
  final icons = MdiIcons();
  BuildContext _mainBuildContext;
  final Map<String, ActionIntentHandler> _actionIntentHandlers = {};

  Timer _subscriptionWatchdog;

  ApplicationStateNotifier stateNotifier;

  bool _initialized = false;
  bool get initialized => _initialized;

  factory FlutterApplicationService.of(ApplicationService service) =>
      service as FlutterApplicationService;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _prefs = await SharedPreferences.getInstance();

    stateNotifier = ApplicationStateNotifier(this);
    settings = FlutterApplicationSettings(_prefs, stateNotifier) as T;

    _initActionIntentHandlers();

    await configure(
      SharedPreferencesConnectionsConfiguration(_prefs),
      createTypeConverter(this),
      createFeatureConverter(this),
      connectSynchronously: false,
    );

    _initialized = true;
  }

  void _initActionIntentHandlers() {
    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_LOGIN] =
        ActionIntentHandler(
      onBeforeCall: (ActionMeta actionMeta, List args) async {
        var usernameArg = getActionArgByIntent(
            actionMeta, Features.TYPE_INTENT_VALUE_USERNAME);
        Validate.notNull(usernameArg,
            'The action ${getActionMetaDisplayLabel(actionMeta)} should have the username argument');

        var passwordArg = getActionArgByIntent(
            actionMeta, Features.TYPE_INTENT_VALUE_PASSWORD);
        Validate.notNull(passwordArg,
            'The action ${getActionMetaDisplayLabel(actionMeta)} should have the password argument');

        var username = args[actionMeta.getArgIndex(usernameArg.name)];
        var password = args[actionMeta.getArgIndex(passwordArg.name)];

        await changeActiveConnectionCredentials(username, password);
      },
      onAfterCall: (ActionMeta actionMeta, List args,
          ActionCallResultInfo resultInfo) async {
        await spongeService.clearActions();
        ApplicationProvider.of(mainBuildContext)
            .updateConnection(spongeService.connection);
      },
      onCallError: (ActionMeta actionMeta, List args) async {
        // In case of error, set the connection to anonymous.
        await changeActiveConnectionCredentials(null, null);
      },
      onIsAllowed: (ActionMeta actionMeta) => !logged,
    );

    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_LOGOUT] =
        ActionIntentHandler(
      onAfterCall: (ActionMeta actionMeta, List args,
          ActionCallResultInfo resultInfo) async {
        await changeActiveConnectionCredentials(null, null);

        await spongeService.clearActions();
        ApplicationProvider.of(mainBuildContext)
            .updateConnection(spongeService.connection);
      },
      onCallError: (ActionMeta actionMeta, List args) async {
        await spongeService.clearActions();
        // In case of error, set the connection to anonymous.
        await changeActiveConnectionCredentials(null, null);

        ApplicationProvider.of(mainBuildContext)
            .updateConnection(spongeService.connection);
      },
      onIsAllowed: (ActionMeta actionMeta) => logged,
    );

    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_SIGN_UP] =
        ActionIntentHandler(
      onIsAllowed: (ActionMeta actionMeta) => !logged,
    );

    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_SUBSCRIPTION] =
        ActionIntentHandler(
      onPrepare: (ActionMeta actionMeta, List args) {
        args[_getSubscribeEventNamesActionArgIndex(actionMeta)] =
            activeConnection?.subscriptionEventNames ?? [];
        args[_getSubscribeSubscribeActionArgIndex(actionMeta)] =
            activeConnection?.subscribe ?? false;
      },
      onAfterCall: (ActionMeta actionMeta, List args,
          ActionCallResultInfo resultInfo) async {
        // Get the event names argument.
        var eventNamesArg =
            args[_getSubscribeEventNamesActionArgIndex(actionMeta)];
        Validate.isTrue(eventNamesArg is List,
            'The action ${getActionMetaDisplayLabel(actionMeta)} ${Features.TYPE_INTENT_VALUE_EVENT_NAMES} argument value should be a list');

        // Get the subscribe argument.
        var subscribeArg =
            args[_getSubscribeSubscribeActionArgIndex(actionMeta)];
        Validate.isTrue(subscribeArg is bool,
            'The action ${getActionMetaDisplayLabel(actionMeta)} ${Features.TYPE_INTENT_VALUE_SUBSCRIBE} argument value should be a boolean');

        // Modify the subscription configuration.
        await changeActiveConnectionSubscription(
            (eventNamesArg as List)?.cast(), subscribeArg as bool);

        // Subscribe.
        await subscribe(spongeService);
      },
    );

    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_RELOAD] =
        ActionIntentHandler(
      onAfterCall: (ActionMeta actionMeta, List args,
              ActionCallResultInfo resultInfo) async =>
          await _reset(),
    );

    _actionIntentHandlers[Features.ACTION_INTENT_VALUE_RESET] =
        ActionIntentHandler(
      onAfterCall: (ActionMeta actionMeta, List args,
              ActionCallResultInfo resultInfo) async =>
          await _reset(),
    );
  }

  Future<void> _reset() async {
    await spongeService.clearActions();
    ApplicationProvider.of(mainBuildContext)
        .updateConnection(spongeService.connection, force: true);
  }

  int _getSubscribeEventNamesActionArgIndex(ActionMeta actionMeta) {
    DataType eventNamesType = getActionArgByIntent(
        actionMeta, Features.TYPE_INTENT_VALUE_EVENT_NAMES);
    Validate.notNull(eventNamesType,
        'The action ${getActionMetaDisplayLabel(actionMeta)} should have the ${Features.TYPE_INTENT_VALUE_EVENT_NAMES} argument');
    Validate.isTrue(
        eventNamesType is ListType && eventNamesType.elementType is StringType,
        'The action ${getActionMetaDisplayLabel(actionMeta)} ${Features.TYPE_INTENT_VALUE_EVENT_NAMES} argument type should be a list of strings');
    return actionMeta.getArgIndex(eventNamesType.name);
  }

  int _getSubscribeSubscribeActionArgIndex(ActionMeta actionMeta) {
    DataType subscribeType =
        getActionArgByIntent(actionMeta, Features.TYPE_INTENT_VALUE_SUBSCRIBE);
    Validate.notNull(subscribeType,
        'The action ${getActionMetaDisplayLabel(actionMeta)} should have the ${Features.TYPE_INTENT_VALUE_SUBSCRIBE} argument');
    Validate.isTrue(subscribeType is BooleanType,
        'The action ${getActionMetaDisplayLabel(actionMeta)} ${Features.TYPE_INTENT_VALUE_SUBSCRIBE} argument type should be a boolean');
    return actionMeta.getArgIndex(subscribeType.name);
  }

  void bindMainBuildContext(BuildContext mainBuildContext) {
    _mainBuildContext = mainBuildContext;
  }

  BuildContext get mainBuildContext => _mainBuildContext;

  TypeGuiProvider getTypeGuiProvider(DataType type) =>
      typeGuiProviderRegistry.getProvider(type);

  @override
  Future<S> createSpongeService(
    SpongeConnection connection,
    TypeConverter typeConverter,
    FeatureConverter featureConverter,
  ) async {
    return FlutterSpongeService(
      connection,
      typeConverter,
      featureConverter,
      typeGuiProviderRegistry,
    ) as S;
  }

  @override
  Future<void> configureSpongeService(
      FlutterSpongeService spongeService) async {
    spongeService.maxEventCount = settings.maxEventCount;
    spongeService.autoUseAuthToken = settings.autoUseAuthToken;
    spongeService.actionIntentHandlers = _actionIntentHandlers;
  }

  @override
  Future<void> startSpongeService(FlutterSpongeService spongeService) async {
    await super.startSpongeService(spongeService);

    // Subscribe but don't block the current thread.
    unawaited(subscribe(spongeService));
  }

  @override
  Future<void> changeActiveConnectionCredentials(
      String username, String password) async {
    await super.changeActiveConnectionCredentials(username, password);

    // Resubscribe.
    await subscribe(spongeService);
  }

  Future<void> subscribe(SpongeService spongeService) async {
    _subscriptionWatchdog?.cancel();
    _subscriptionWatchdog = null;

    if (activeConnection.subscribe) {
      try {
        try {
          var subscription = await spongeService.subscribe();
          if (subscription != null) {
            subscription.eventStream.listen(
              (event) async {
                try {
                  if (subscription.subscribed) {
                    EventData eventData =
                        await spongeService.createEventData(event);
                    _logger.finer(
                        'Subscription ${subscription.id ?? ''} - received event: ${event.id}, ${event.name}, ${event.label}, ${event.attributes}');
                    await spongeService.addEvent(eventData);

                    if (settings.showNewEventNotification) {
                      await showEventNotification(eventData);
                    }
                  }
                } catch (e) {
                  _logger.severe(
                      'Subscription ${subscription.id ?? ''} - event processing error: $e');
                }
              },
              onError: (e) {
                _logger.severe(
                    'Subscription ${subscription.id ?? ''} - error: $e');
              },
              onDone: () {
                _logger.info('Subscription ${subscription.id ?? ''} - done');
              },
            );
          }
        } catch (e) {
          _logger.severe('Subscribe error: $e');
        }
      } finally {
        // Start the watchdog.
        _subscriptionWatchdog = Timer.periodic(
            Duration(seconds: settings.subscriptionWatchdogInterval),
            (timer) async {
          if (activeConnection != null &&
              activeConnection.subscribe &&
              !spongeService.isSubscribed) {
            // Cancel the current watchdog.
            timer.cancel();

            _logger.info('Resubscribing...');
            await subscribe(spongeService);
          }
        });
      }
    } else {
      unawaited(spongeService
          .unsubscribe()
          .catchError((e) => _logger.severe('Unsubscribe error: $e')));
    }
  }

  Future<void> showEventNotification(EventData eventData) async {}
}

class FlutterSpongeService extends SpongeService<FlutterActionData> {
  FlutterSpongeService(
    SpongeConnection connection,
    TypeConverter typeConverter,
    FeatureConverter featureConverter,
    this.typeGuiProviderRegistry, {
    Map<String, ActionIntentHandler> actionIntentHandlers,
  }) : super(connection,
            typeConverter: typeConverter,
            featureConverter: featureConverter,
            actionIntentHandlers: actionIntentHandlers);

  final TypeGuiProviderRegistry typeGuiProviderRegistry;

  @override
  FlutterActionData createActionData(ActionMeta actionMeta) =>
      FlutterActionData(actionMeta, typeGuiProviderRegistry);
}

class EventNotificationState with ChangeNotifier {
  RemoteEvent _lastEvent;

  RemoteEvent get lastEvent => _lastEvent;

  set lastEvent(RemoteEvent value) {
    _lastEvent = value;
    notifyListeners();
  }
}
