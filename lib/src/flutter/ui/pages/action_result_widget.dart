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
import 'package:sponge_flutter_api/src/common/ui/pages/action_result_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/model/flutter_model.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';

class ActionResultWidget extends StatefulWidget {
  ActionResultWidget({
    Key key,
    @required this.actionData,
    @required this.bloc,
  }) : super(key: key);

  final ActionData actionData;
  final ActionCallBloc bloc;

  @override
  _ActionResultWidgetState createState() => _ActionResultWidgetState();
}

class _ActionResultWidgetState extends State<ActionResultWidget>
    implements ActionResultView {
  ActionResultPresenter _presenter;

  @override
  Widget build(BuildContext context) {
    var model = ActionResultViewModel(widget.actionData, widget.bloc);

    _presenter ??= ActionResultPresenter(
        ApplicationProvider.of(context).service, model, this);

    _presenter.updateModel(model);

    return BlocBuilder<ActionCallBloc, ActionCallState>(
      bloc: _presenter.bloc,
      builder: (BuildContext context, ActionCallState state) {
        return _buildResultWidget(context, state);
      },
    );
  }

  Widget _buildResultWidget(BuildContext context, ActionCallState state) {
    if (state is ActionCallStateInitialize) {
      // View the previous state from the ActionData.
      if (_presenter.actionData.calling) {
        return Center(child: CircularProgressIndicator());
      } else if (_presenter.actionData.isSuccess) {
        return _buildActualResultWidget(
            context, _presenter.actionData.resultInfo.result);
      } else if (_presenter.actionData.isError) {
        return _buildErrorWidget(_presenter.actionData.resultInfo.exception);
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
          color: Colors.red,
          child: Container(
            margin: const EdgeInsets.all(5),
            child: Text(
              'Error: $exception',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );

  Widget _buildActualResultWidget(BuildContext context, dynamic result) {
    TypeGuiProvider provider =
        (_presenter.actionData as FlutterActionData).resultProvider;
    var createViewerContext = () => TypeViewerContext(
          '${widget.actionData.actionMeta.name}-result',
          context,
          NoOpUiContextCallbacks(_presenter.service),
          QualifiedDataType(widget.actionData.actionMeta.result),
          result,
          typeLabel: _presenter.resultLabel,
          markNullable: false,
          loading: [],
        );

    return InkWell(
      onTap: () => navigateToExtendedViewer(provider, createViewerContext()),
      child: provider.createCompactViewer(createViewerContext()),
    );
  }
}
