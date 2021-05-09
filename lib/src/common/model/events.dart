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
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';

class AfterSubActionCallEvent {
  AfterSubActionCallEvent(
    this.subActionSpec,
    this.state, {
    this.index,
    this.errorAlreadyHandled = false,
  });

  final SubActionSpec subActionSpec;
  final ActionCallState state;
  final int index;
  final bool errorAlreadyHandled;
}

abstract class ValueStateChangedEvent {
  ValueStateChangedEvent(this.qType, this.value);

  final QualifiedDataType qType;
  final dynamic value;
}

class SaveValueEvent extends ValueStateChangedEvent {
  SaveValueEvent(QualifiedDataType qType, dynamic value) : super(qType, value);
}

class UpdateValueEvent extends ValueStateChangedEvent {
  UpdateValueEvent(QualifiedDataType qType, dynamic value)
      : super(qType, value);
}

class ActivateValueEvent extends ValueStateChangedEvent {
  ActivateValueEvent(QualifiedDataType qType, dynamic value)
      : super(qType, value);
}
