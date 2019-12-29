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

import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';
import 'package:sponge_flutter_api/src/app/digits/digits_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/actions.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/connections.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/events.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/settings.dart';

class Routes {
  static const String ACTIONS = '/';
  static const String EVENTS = '/events';
  static const String CONNECTIONS = '/connections';
  static const String SETTINGS = '/settings';
  static const String APP_DIGITS = '/app/digits';

  static void configureRoutes(Router router) {
    router.define(ACTIONS,
        handler: Handler(
            handlerFunc:
                (BuildContext context, Map<String, List<String>> params) =>
                    ActionsWidget()));
    router.define(EVENTS,
        handler: Handler(
            handlerFunc:
                (BuildContext context, Map<String, List<String>> params) =>
                    EventsWidget()));
    router.define(CONNECTIONS,
        handler: Handler(
            handlerFunc:
                (BuildContext context, Map<String, List<String>> params) =>
                    ConnectionsWidget()));
    router.define(SETTINGS,
        handler: Handler(
            handlerFunc:
                (BuildContext context, Map<String, List<String>> params) =>
                    SettingsWidget()));
    router.define(APP_DIGITS,
        handler: Handler(
            handlerFunc:
                (BuildContext context, Map<String, List<String>> params) =>
                    DigitsWidget()));
  }
}
