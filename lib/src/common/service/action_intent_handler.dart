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

import 'package:sponge_client_dart/sponge_client_dart.dart';

typedef OnActionIntentPrepareCallback = void Function(
    ActionMeta actionMeta, List args);
typedef OnActionIntentCallback = Future<void> Function(
    ActionMeta actionMeta, List args);
typedef OnActionIntentAfterCallback = Future<void> Function(
    ActionMeta actionMeta, List args, ActionCallResultInfo resultInfo);
typedef OnActionIntentIsAllowedCallback = bool Function(ActionMeta actionMeta);

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
