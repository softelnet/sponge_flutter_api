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
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';

class ActionCallBloc {
  ActionCallBloc(
    SpongeService spongeService,
    String actionName, {
    @required bool saveState,
    this.startState,
  }) {
    onActionCall = BehaviorSubject<List>();
    state = onActionCall
        //.debounce(const Duration(milliseconds: 250))
        // If another call is initiated, the previous call is discarded so we don't deliver stale results.
        .switchMap<ActionCallState>((List args) =>
            _callAction(spongeService, actionName, args, saveState));

    if (startState != null) {
      // The optional initial state to deliver to the screen.
      state = state.startWith(startState);
    }

    state = state.asBroadcastStream();
  }

  BehaviorSubject<List> onActionCall;
  Stream<ActionCallState> state;

  ActionCallState startState;

  Stream<ActionCallState> _callAction(SpongeService spongeService,
      String actionName, List args, bool saveState) async* {
    ActionData actionData;
    if (args == null) {
      yield ActionCallStateClear();
    } else {
      try {
        yield ActionCallStateCalling();
        actionData = await spongeService.getAction(actionName, required: false);
        if (actionData == null) {
          yield ActionCallStateNoAction();
        } else {
          if (saveState) {
            // Only one call of this action (using ActionData) at a time.
            actionData.calling = true;
          }

          final resultInfo = await spongeService.callAction(
            actionData.actionMeta,
            args: args,
            saveArgsAndResult: saveState,
          );
          yield ActionCallStateEnded(resultInfo);
        }
      } catch (e) {
        yield ActionCallStateError(e);
      } finally {
        if (saveState && actionData != null) {
          actionData.calling = false;
        }
      }
    }
  }

  void dispose() => onActionCall.close();

  void clear() => onActionCall.add(null);
}
