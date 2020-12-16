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

import 'package:flutter/material.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_bloc.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/util/model_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/pages/action_result_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';

Future<void> callActionImmediately({
  @required BuildContext context,
  void Function() onBeforeCall,
  void Function() onAfterCall,
  @required ActionData actionData,
  @required ActionCallBloc bloc,
  @required bool showResultDialog,
  @required bool showNoResultDialog,
}) async {
  var resultInfo;

  if (onBeforeCall != null) {
    onBeforeCall();
  }

  try {
    bloc.add(actionData.args);

    // Wait for the server response.
    var callState =
        await bloc.firstWhere((state) => state.isFinal, orElse: () => null);

    if (callState is ActionCallStateEnded) {
      resultInfo = callState.resultInfo;
    } else if (callState is ActionCallStateError) {
      throw callState.error;
    }
  } finally {
    if (onAfterCall != null) {
      onAfterCall();
    }
  }
  actionData.resultInfo = resultInfo;
  if (!(actionData.actionMeta.result is VoidType &&
          actionData.actionMeta.result.label == null) ||
      showNoResultDialog) {
    if (showResultDialog) {
      await showActionResultDialog(
        context: context,
        actionData: actionData,
        bloc: bloc,
      );
    }
  }
}

Future<ActionData> showActionCall(
  BuildContext context,
  ActionData actionData, {
  @required WidgetBuilder builder,
}) async {
  return await Navigator.push(
      context, createPageRoute<ActionData>(context, builder: builder));
}

Future<void> showActionResultDialog({
  @required BuildContext context,
  @required ActionData actionData,
  ActionCallBloc bloc,
  bool autoClosing = false,
}) async {
  // The holder for a dialog BuildContext.
  BuildContext dialogContext;

  if (autoClosing) {
    WidgetsBinding.instance.addPostFrameCallback((_) => bloc.listen((state) {
          if (state is ActionCallStateEnded && dialogContext != null) {
            Navigator.of(dialogContext).pop(null);
          }
        }));
  }

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      dialogContext = context;

      return AlertDialog(
        title:
            Text(ModelUtils.getActionMetaDisplayLabel(actionData.actionMeta)),
        content: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ActionResultWidget(
              actionData: actionData,
              bloc: bloc,
            ),
          ),
        ),
        actions: <Widget>[
          FlatButton(
            child: const Text('CLOSE'),
            onPressed: () {
              bloc.clear();
              Navigator.of(context).pop(null);
            },
          ),
        ],
      );
    },
  );
}
