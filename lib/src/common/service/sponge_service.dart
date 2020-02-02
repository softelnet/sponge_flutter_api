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

import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_bloc.dart';
import 'package:sponge_flutter_api/src/common/bloc/event_received_bloc.dart';
import 'package:sponge_flutter_api/src/common/bloc/forwarding_bloc.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_grpc_client_dart/sponge_grpc_client_dart.dart';
import 'package:synchronized/synchronized.dart';

/// Service for one connection to one Sponge server.
class SpongeService<AD extends ActionData> {
  SpongeService(
    this._connection, {
    this.typeConverter,
    this.actionIntentHandlers = const {},
  });

  static final Logger _logger = Logger('SpongeService');

  TypeConverter typeConverter;
  final SpongeConnection _connection;
  SpongeRestClient _client;
  SpongeRestClient get client => _client;
  SpongeGrpcClient _grpcClient;
  SpongeGrpcClient get grpcClient => _grpcClient;

  final Lock _lock = Lock(reentrant: true);
  List<AD> _actions;
  Map<String, ActionCallBloc> _actionCallBloc = {};
  Map<String, ActionIntentHandler> actionIntentHandlers;

  ClientSubscription _subscription;
  ClientSubscription get subscription => _subscription;

  bool get isSubscribed => _subscription?.subscribed ?? false;

  final List<EventData> _events = [];
  int _maxEventCount = 0;
  int get maxEventCount => _maxEventCount;
  set maxEventCount(int value) {
    _ensureEventsCount(value, value <= 0);
    _maxEventCount = value;
  }

  bool autoUseAuthToken = true;

  bool get connected => _client != null;
  SpongeConnection get connection => _connection;

  EventReceivedBloc eventReceivedBloc;
  ForwardingBloc<bool> subscriptionBloc;

  Future<void> open() async {
    _client = _createSpongeClient(
      _connection,
      typeConverter: typeConverter,
      autoUseAuthToken: autoUseAuthToken,
    );

    Map<String, dynamic> features = await _client.getFeatures();
    if (features[SpongeClientConstants.REMOTE_API_FEATURE_GRPC_ENABLED] ??
        false) {
      _grpcClient = createSpongeGrpcClient(_client, _connection);
    }

    eventReceivedBloc?.dispose();
    eventReceivedBloc = EventReceivedBloc();
    unawaited(subscriptionBloc?.close());
    subscriptionBloc = ForwardingBloc<bool>(initialValue: false);
  }

  bool isActionAllowedByIntent(ActionMeta actionMeta) {
    var intent = actionMeta.features[Features.INTENT];
    return intent != null
        ? (actionIntentHandlers[intent]?.onIsAllowed(actionMeta) ?? true)
        : true;
  }

  void prepareActionByIntent(ActionData actionData) {
    var intent = actionData.actionMeta.features[Features.INTENT];
    if (intent != null) {
      actionIntentHandlers[intent]
          ?.onPrepare(actionData.actionMeta, actionData.args);
    }
  }

  bool isActionSupported(ActionMeta actionMeta) {
    bool hasStream = DataTypeUtils.hasSubType(
            actionMeta.result, DataTypeKind.STREAM) ||
        actionMeta.args
            .any((arg) => DataTypeUtils.hasSubType(arg, DataTypeKind.STREAM));
    if (hasStream) {
      return false;
    }

    return true;
  }

  Future<ActionCallResultInfo> callAction(
    ActionMeta actionMeta, {
    List args,
    bool saveArgsAndResult = true,
  }) async {
    AD actionData = Validate.notNull(
        _actions?.singleWhere((a) => a.actionMeta.name == actionMeta.name),
        'Action ${actionMeta.name} not found locally');

    var actionIntent = actionData.actionMeta.features[Features.INTENT];

    if (saveArgsAndResult) {
      actionData.args = args;
      actionData.resultInfo = null;
    }

    // Handle action intent before call.
    if (actionIntent != null) {
      await actionIntentHandlers[actionIntent]
          ?.onBeforeCall(actionData.actionMeta, args);
    }

    ActionCallResultInfo resultInfo;
    try {
      var result = await _client.call(actionMeta.name, args, actionMeta);
      resultInfo = ActionCallResultInfo(result: result);

      // Handle action intent after call.
      if (actionIntent != null) {
        await actionIntentHandlers[actionIntent]
            ?.onAfterCall(actionData.actionMeta, args, resultInfo);
      }
    } catch (e) {
      resultInfo = ActionCallResultInfo(exception: e);

      // Handle action intent after call.
      if (actionIntent != null) {
        await actionIntentHandlers[actionIntent]
            ?.onCallError(actionData.actionMeta, args);
      }
      rethrow;
    } finally {
      if (saveArgsAndResult) {
        actionData.resultInfo = resultInfo;
      }
    }

    return resultInfo;
  }

  Future<void> clearActions() async {
    return await _lock.synchronized(() async {
      await _client?.clearCache();
      _actionCallBloc = {};
      _actions = null;
    });
  }

  Future<void> close() async {
    eventReceivedBloc?.dispose();
    await _grpcClient?.close(terminate: true);
  }

  Future<AD> getAction(String actionName, {bool required = true}) async {
    await getActions();
    return getCachedAction(actionName, required: required);
  }

  ActionCallBloc getActionCallBloc(String actionName) =>
      _actionCallBloc[actionName];

  Future<List<AD>> getActions([bool refresh = false]) async {
    return await _lock.synchronized(() async {
      if (_actions != null && !refresh) {
        return _actions;
      }

      // Clear BLoCs.
      _actions?.forEach((actionData) =>
          _actionCallBloc[actionData.actionMeta.name]?.dispose());
      _actionCallBloc = {};

      _actions = null;

      List<ActionMeta> actionMetaList =
          await _client.getActions(metadataRequired: true);
      List<AD> actionDataList =
          actionMetaList.map((meta) => createActionData(meta)).toList();

      // Create BLoCs.
      actionDataList.forEach((actionData) =>
          _actionCallBloc[actionData.actionMeta.name] = ActionCallBloc(
            this,
            actionData.actionMeta.name,
            saveState: actionData.hasCacheableArgs,
          ));

      // Set actions cache at the end of this method.
      _actions = actionDataList;

      return _actions;
    });
  }

  AD createActionData(ActionMeta actionMeta) => ActionData(actionMeta) as AD;

  AD getCachedAction(String actionName, {bool required = true}) {
    var result = _actions?.singleWhere((a) => a.actionMeta.name == actionName,
        orElse: () => null);
    Validate.isTrue(
        result != null || !required, 'Action $actionName not found');

    return result;
  }

  void setupSubActionSpec(SubActionSpec subActionSpec, DataType sourceType) {
    subActionSpec.setup(
        getCachedAction(subActionSpec.actionName, required: true).actionMeta,
        sourceType);
  }

  Future<String> getVersion() => _client.getVersion();

  Future<ReloadResponse> reload() => _client.reload();

  Future<ClientSubscription> subscribe() async {
    return await _lock.synchronized(() async {
      var shouldSubscribe =
          _connection.subscriptionEventNames?.isNotEmpty ?? false;

      if (shouldSubscribe) {
        if (_subscription != null) {
          unawaited(_subscription.close().catchError(
              (e) => _logger.severe('Subscription closing error: $e')));
        }

        var newSubscription = _grpcClient.subscribe(
            _connection.subscriptionEventNames,
            registeredTypeRequired: true);
        _subscription = newSubscription;

        subscriptionBloc.add(true);

        _subscription.eventStream.listen(null, onDone: () {
          if (newSubscription == _subscription) {
            subscriptionBloc.add(false);
          }
        });

        return _subscription;
      } else {
        if (_subscription != null) {
          unawaited(_subscription.close().catchError(
              (e) => _logger.severe('Subscription closing error: $e')));
        }
      }

      return null;
    });
  }

  Future<void> unsubscribe() async {
    await _lock.synchronized(() async {
      await _subscription?.close();
      _subscription = null;
      subscriptionBloc.add(false);
    });
  }

  // Future<void> resubscribe() async {
  //   await _lock.synchronized(() async {
  //     bool subscribed = _subscription != null;

  //     await unsubscribe();

  //     if (subscribed) {
  //       await subscribe();
  //     }
  //   });
  // }

  List<EventData> getEvents() => _events;

  EventData getEvent(String eventId) =>
      _events?.singleWhere((eventData) => eventData.event.id == eventId,
          orElse: () => null);

  Future<EventData> createEventData(RemoteEvent event) async =>
      EventData(event, await _client.getEventType(event.name));

  Future<void> addEvent(EventData eventData) async {
    _ensureEventsCount(maxEventCount - 1, maxEventCount <= 0);
    _events.add(eventData);

    eventReceivedBloc?.onEvent?.add(eventData);
  }

  void removeEvent(String eventId) {
    _events.removeWhere((eventData) => eventData.event.id == eventId);
  }

  void clearEvents() {
    _events.clear();
  }

  void _ensureEventsCount(int maxCount, bool isInfinite) {
    if (!isInfinite && _events.length > maxCount) {
      _events.removeRange(0, _events.length - maxCount);
    }
  }

  Future<bool> isGrpcEnabled() async =>
      (await _client?.getFeatures())[
          SpongeClientConstants.REMOTE_API_FEATURE_GRPC_ENABLED] ??
      false;

  Future<ActionData> findIntentAction(String intent) async {
    return (await getActions()).firstWhere(
        (actionData) =>
            actionData.actionMeta.features[Features.INTENT] == intent,
        orElse: () => null);
  }

  Future<ActionData> findSubscriptionAction() async {
    return await findIntentAction(Features.ACTION_INTENT_VALUE_SUBSCRIPTION);
  }

  Future<ActionData> findDefaultEventHandlerAction() async {
    return await findIntentAction(Features.ACTION_INTENT_DEFAULT_EVENT_HANDLER);
  }

  Future<ActionData> findEventHandlerAction(EventData eventData) async {
    // Get the fresh event type.
    var handlerActionName = (await client.getEventType(eventData.event.name))
        ?.features[Features.EVENT_HANDLER_ACTION];

    ActionData globalActionData = handlerActionName != null
        ? (await getAction(handlerActionName))
        : (await findDefaultEventHandlerAction());
    if (globalActionData == null) {
      return null;
    }

    // Create a new action data to prevent remembering of arguments.
    var actionData = ActionData(globalActionData.actionMeta);

    // Set all event arguments using the following convention.
    for (var i = 0; i < actionData.actionMeta.args.length; i++) {
      DataType argType = actionData.actionMeta.args[i];
      if (argType is ObjectType &&
          argType.className ==
              SpongeClientConstants.REMOTE_EVENT_OBJECT_TYPE_CLASS_NAME) {
        actionData.args[i] = eventData.event;
      }
    }

    return actionData;
  }

  Future<bool> isActionActive(
    String actionName, {
    List args,
  }) async {
    return (await client?.isActionActive(
                [IsActionActiveEntry(name: actionName, args: args)]))
            ?.first ??
        false;
  }

  static Future<String> testConnection(SpongeConnection connection) async =>
      await _createSpongeClient(connection).getVersion();

  static SpongeRestClient _createSpongeClient(
    SpongeConnection connection, {
    TypeConverter typeConverter,
    bool autoUseAuthToken = true,
  }) {
    if (!connection.anonymous &&
        (connection.username == null || connection.password == null)) {
      throw UsernamePasswordNotSetException(connection.name);
    }

    return SpongeRestClient(
      SpongeRestClientConfiguration(
        connection.url,
        username: connection.anonymous ? null : connection.username,
        password: connection.anonymous ? null : connection.password,
        autoUseAuthToken: autoUseAuthToken,
      ),
      typeConverter: typeConverter,
    );
  }

  SpongeGrpcClient createSpongeGrpcClient(
      SpongeRestClient client, SpongeConnection connection) {
    return DefaultSpongeGrpcClient(
      client,
      channelOptions: ChannelOptions(
        credentials: connection.isSecure()
            ? ChannelCredentials.secure()
            : ChannelCredentials.insecure(),
      ),
    );
  }
}

class UsernamePasswordNotSetException implements Exception {
  const UsernamePasswordNotSetException(this.connectionName);

  final String connectionName;

  @override
  String toString() => 'Username or password not set for $connectionName';
}

typedef void OnActionIntentPrepareCallback(ActionMeta actionMeta, List args);
typedef Future<void> OnActionIntentCallback(ActionMeta actionMeta, List args);
typedef Future<void> OnActionIntentAfterCallback(
    ActionMeta actionMeta, List args, ActionCallResultInfo resultInfo);
typedef bool OnActionIntentIsAllowedCallback(ActionMeta actionMeta);

class ActionIntentHandler {
  ActionIntentHandler({
    OnActionIntentPrepareCallback onPrepare,
    OnActionIntentCallback onBeforeCall,
    OnActionIntentAfterCallback onAfterCall,
    OnActionIntentCallback onCallError,
    OnActionIntentIsAllowedCallback onIsAllowed,
  }) {
    this.onPrepare = onPrepare ?? ((ActionMeta actionMeta, List args) {});
    this.onBeforeCall =
        onBeforeCall ?? ((ActionMeta actionMeta, List args) async {});
    this.onAfterCall = onAfterCall ??
        ((ActionMeta actionMeta, List args,
            ActionCallResultInfo resultInfo) async {});
    this.onCallError =
        onCallError ?? ((ActionMeta actionMeta, List args) async {});
    this.onIsAllowed = onIsAllowed ?? ((ActionMeta actionMeta) => true);
  }

  OnActionIntentPrepareCallback onPrepare;
  OnActionIntentCallback onBeforeCall;
  OnActionIntentAfterCallback onAfterCall;
  OnActionIntentCallback onCallError;
  OnActionIntentIsAllowedCallback onIsAllowed;
}
