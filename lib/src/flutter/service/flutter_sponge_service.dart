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

import 'package:flutter/foundation.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/service/action_intent_handler.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';
import 'package:sponge_flutter_api/src/flutter/model/flutter_model.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';

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
