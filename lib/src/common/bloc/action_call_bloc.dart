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
import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';

class ActionCallBloc extends Bloc<List, ActionCallState> {
  ActionCallBloc({
    @required SpongeService spongeService,
    @required String actionName,
    ActionCallState initialState,
    @required bool saveState,
  })  : _spongeService = spongeService,
        _actionName = actionName,
        _saveState = saveState,
        super(initialState ?? ActionCallStateInitialize());

  final SpongeService _spongeService;
  final String _actionName;
  final bool _saveState;

  // A non null event indicationg a `clear` event.
  static const _clearArgsEvent = [];

  @override
  Stream<ActionCallState> mapEventToState(List actionArgs) {
    return _callAction(_spongeService, _actionName, actionArgs, _saveState);
  }

  Stream<ActionCallState> _callAction(SpongeService spongeService,
      String actionName, List args, bool saveState) async* {
    ActionData actionData;
    if (identical(args, _clearArgsEvent)) {
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

  void clear() => add(_clearArgsEvent);
}
