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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_bloc.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/pages/action_list_item_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/pages/action_result_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/model_gui_utils.dart';

class ActionListItem extends StatefulWidget {
  ActionListItem({
    Key key,
    @required this.actionData,
    @required this.onActionCall,
    @required this.showQualifiedName,
  }) : super(key: key);

  final ActionData actionData;
  final OnActionCallCalllback onActionCall;
  final bool showQualifiedName;

  @override
  _ActionListItemState createState() => _ActionListItemState();
}

class _ActionListItemState extends State<ActionListItem>
    implements ActionListItemView {
  ActionListItemPresenter _presenter;

  final _biggerFont = const TextStyle(fontSize: 18.0);
  bool showCallIcon = true;
  bool callTapOnlyOnCallIcon = true;
  final _showResultAsSubtitle = false;

  @override
  Widget build(BuildContext context) {
    var service = ApplicationProvider.of(context).service;
    var model = ActionListItemViewModel(widget.actionData, widget.onActionCall);

    _presenter ??= ActionListItemPresenter(service, model, this);
    _presenter.updateModel(model);

    callTapOnlyOnCallIcon = !service.settings.actionCallOnTap;

    return BlocBuilder<ActionCallBloc, ActionCallState>(
        cubit: _presenter.bloc,
        builder: (BuildContext context, ActionCallState state) {
          _presenter.state = state;

          // TODO Wrap in a widget to disable when the action is called/checked if it is active.
          return Card(
            child: Tooltip(
              message: _presenter.tooltip,
              child: _buildMainWidget(context),
            ),
          );
        });
  }

  Widget _buildMainWidget(BuildContext context) {
    var resultWidget =
        showCallIcon ? _buildResultWidget() : _buildAdvancedSubtitle(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0.0, horizontal: 8.0),
          leading: _getActionIcon(context),
          trailing: showCallIcon &&
                  _presenter.isEffectivelyCallable /*&& callTapOnlyOnCallIcon*/
              ? Tooltip(
                  message: _presenter.isInstantActionCallAllowed
                      ? 'Run the action'
                      : 'Set the arguments and run the action',
                  child: InkResponse(
                    child: _presenter.isInstantActionCallAllowed
                        ? Icon(Icons.play_arrow,
                            color: getCallIconColor(context))
                        : Icon(Icons.play_circle_outline,
                            color: getCallIconColor(context)),
                    onTap: () => _onActionCall(context)
                        .catchError((e) => handleError(context, e)),
                  ),
                )
              : null,
          title: Text(
            widget.showQualifiedName
                ? _presenter.qualifiedLabel
                : _presenter.label,
            style: _biggerFont,
          ),
          subtitle: _showResultAsSubtitle
              ? (showCallIcon
                  ? _buildResultWidget()
                  : _buildAdvancedSubtitle(context))
              : null,
          onTap: callTapOnlyOnCallIcon
              ? null
              : () => _onActionCall(context)
                  .catchError((e) => handleError(context, e)),
        ),
        if (!_showResultAsSubtitle && resultWidget != null)
          Container(
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
            alignment: Alignment.centerLeft,
            child: resultWidget,
          ),
      ],
    );
  }

  Widget _buildResultWidget() {
    if (_presenter.bloc == null) {
      return null;
    }

    if (_presenter.state is ActionCallStateInitialize &&
            (_presenter.actionData.calling ||
                _presenter.actionData.hasResponse) ||
        _presenter.state is ActionCallStateCalling ||
        _presenter.state is ActionCallStateEnded ||
        _presenter.state is ActionCallStateError) {
      return ActionResultWidget(
          actionData: _presenter.actionData, bloc: _presenter.bloc);
    } else {
      return null;
    }
  }

  Widget _getActionIcon(BuildContext context) {
    var internalIconSupplier = () => Tooltip(
          message: 'The number of action arguments',
          child: Icon(
            getActionArgsIconData(_presenter.actionMeta.args?.length ?? 0),
            color: getIconColor(context),
          ),
        );

    switch (_presenter.service.settings.actionIconsView) {
      case ActionIconsView.custom:
        return getActionIcon(context, _presenter.service,
                _presenter.viewModel.actionData.actionMeta) ??
            internalIconSupplier();
      case ActionIconsView.internal:
        return internalIconSupplier();
      case ActionIconsView.none:
        return null;
    }

    return null;
  }

  Widget _buildAdvancedSubtitle(BuildContext context) {
    var resultWidget = _buildResultWidget();

    return Column(children: [
      if (resultWidget != null)
        Container(
          child: resultWidget,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(top: 5.0),
        ),
      _buildButtonBar(context),
    ]);
  }

  Widget _buildButtonBar(BuildContext context) {
    return ButtonBar(
      buttonPadding: EdgeInsets.zero,
      alignment: MainAxisAlignment.end,
      children: <Widget>[
        TextButton(
          onPressed: () =>
              _onActionCall(context).catchError((e) => handleError(context, e)),
          child: Text('RUN'),
        )
      ],
    );
  }

  Future<void> _onActionCall(BuildContext context) async {
    await _presenter.onActionCall();

    if (mounted) {
      setState(() {});
    }
  }
}
