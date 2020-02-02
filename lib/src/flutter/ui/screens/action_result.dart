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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/sponge_flutter_api.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_bloc.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/flutter/flutter_model.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/ui_context.dart';

class ActionResultWidget extends StatefulWidget {
  ActionResultWidget({
    Key key,
    @required this.actionData,
    @required this.bloc,
  }) : super(key: key);

  // TODO Refactor to the presenter.
  final ActionData actionData;
  final ActionCallBloc bloc;

  @override
  _ActionResultWidgetState createState() => _ActionResultWidgetState();
}

class _ActionResultWidgetState extends State<ActionResultWidget> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActionCallBloc, ActionCallState>(
        bloc: widget.bloc,
        builder: (BuildContext context, ActionCallState state) {
          return _buildResultWidget(context, state);
        });
  }

  Widget _buildResultWidget(BuildContext context, ActionCallState state) {
    if (state is ActionCallStateInitialize) {
      // View the previous state in ActionData.
      if (widget.actionData.calling) {
        return Center(child: CircularProgressIndicator());
      } else if (widget.actionData.isSuccess) {
        return _buildActualResultWidget(
            context, widget.actionData.resultInfo.result);
      } else if (widget.actionData.isError) {
        return _buildErrorWidget(widget.actionData.resultInfo.exception);
      }
    } else if (state is ActionCallStateCalling) {
      return Center(child: CircularProgressIndicator());
    } else if (state is ActionCallStateEnded) {
      return _buildActualResultWidget(context, state.resultInfo.result);
    } else if (state is ActionCallStateError) {
      return _buildErrorWidget(state.error);
    }

    return Container();
  }

  Widget _buildErrorWidget(dynamic exception) => SingleChildScrollView(
        child: Container(
          child: Container(
            child: Text(
              'Error: $exception',
              style: TextStyle(color: Colors.white),
            ),
            margin: EdgeInsets.all(5),
          ),
          color: Colors.red,
        ),
      );

  // TODO Refactor to the presenter.
  String get resultLabel =>
      widget.actionData.actionMeta.result?.label ?? 'Result';

  static UnitTypeGuiProvider getActionResultProvider(
      BuildContext context, ActionData actionData) {
    if (actionData is FlutterActionData) {
      return actionData.resultProvider;
    }

    return ApplicationProvider.of(context)
        .service
        .typeGuiProvider
        .getProvider(actionData.actionMeta.result);
  }

  Widget _buildActualResultWidget(BuildContext context, dynamic result) {
    UnitTypeGuiProvider provider =
        getActionResultProvider(context, widget.actionData);
    var createViewerContext = () => TypeViewerContext(
          '${widget.actionData.actionMeta.name}-result',
          context,
          NoOpUiContextCallbacks(),
          QualifiedDataType(null, widget.actionData.actionMeta.result),
          result,
          typeLabel: resultLabel,
          markNullable: false,
          loading: [],
        );

    return InkWell(
      onTap: () => provider.navigateToExtendedViewer(createViewerContext()),
      child: provider.createCompactViewer(createViewerContext()),
    );
  }
}
