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
import 'package:modal_progress_hud/modal_progress_hud.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_bloc.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/bloc/provide_action_args_state.dart';
import 'package:sponge_flutter_api/src/common/model/action_call_session.dart';
import 'package:sponge_flutter_api/src/common/ui/pages/action_call_mvp.dart';
import 'package:sponge_flutter_api/src/common/util/model_utils.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/mvp/pages/action_call_flutter_presenter.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/action_call_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/error_widgets.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/sub_action/sub_actions_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/widgets.dart';

class ActionCallPage extends StatefulWidget {
  ActionCallPage({
    Key key,
    @required this.actionData,
    this.readOnly = false,
    this.callImmediately = false,
    this.showResultDialog = true,
    this.showResultDialogIfNoResult = true,
    this.verifyIsActive = true,
    @required this.bloc,
    this.header,
    this.title,
  }) : super(key: key);

  final ActionData actionData;
  final bool readOnly;
  final bool callImmediately;
  final bool showResultDialog;
  final bool showResultDialogIfNoResult;
  final bool verifyIsActive;
  final ActionCallBloc bloc;
  final String header;
  final String title;

  @override
  _ActionCallPageState createState() => _ActionCallPageState();
}

class _ActionCallPageState extends State<ActionCallPage>
    implements ActionCallView {
  FlutterActionCallPresenter _presenter;
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TypeGuiProvider _mainArgsGuiProvider;

  @override
  void dispose() {
    _presenter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _presenter ??= FlutterActionCallPresenter(
      ApplicationProvider.of(context).service,
      ActionCallViewModel(widget.actionData),
      this,
    )..init(
        verifyIsActive: widget.verifyIsActive,
        bloc: widget.bloc,
        title: widget.title,
        callImmediately: widget.callImmediately,
      );

    _presenter.ensureRunning();

    _mainArgsGuiProvider ??= _presenter.service
        .getTypeGuiProvider(widget.actionData.argsAsRecordType);

    var subActionsWidget = _resolveSubActionsWidget(context);

    return WillPopScope(
      child: SwipeDetector(
        onSwipe:
            _presenter.canSwipeToClose ? (context) => _onCancel(context) : null,
        child: Scaffold(
          appBar: AppBar(
            title: _buildTitle(context),
            actions:
                subActionsWidget != null ? <Widget>[subActionsWidget] : null,
          ),
          body: SafeArea(
            child: ModalProgressHUD(
              child: _buildIsActiveWidget(context),
              inAsyncCall: _presenter.busy,
            ),
          ),
        ),
      ),
      onWillPop: () async {
        _onClose();
        return true;
      },
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Tooltip(
      child: Text(
        _presenter.title,
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
      message: _presenter.title,
    );
  }

  void _onClose() {
    _presenter.rebindActionData(widget.actionData);
  }

  Widget _buildIsActiveWidget(BuildContext context) {
    return widget.verifyIsActive && _presenter.actionMeta.activatable
        ? FutureBuilder<bool>(
            future: _presenter.isActionActive(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return snapshot.data
                    ? _buildProvideArgsWidget(context)
                    : Center(
                        child: NotificationPanelWidget(
                        notification: '${_presenter.title} is inactive.',
                        type: NotificationPanelType.info,
                      ));
              } else if (snapshot.hasError) {
                return Center(
                  child: NotificationPanelWidget(
                    notification: snapshot.error,
                    type: NotificationPanelType.error,
                  ),
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          )
        : _buildProvideArgsWidget(context);
  }

  Widget _buildProvideArgsWidget(BuildContext context) {
    return _presenter.hasProvidedArgs
        ? BlocBuilder<ProvideActionArgsBloc, ProvideActionArgsState>(
            cubit: _presenter.provideArgsBloc,
            builder: (BuildContext context, ProvideActionArgsState state) {
              _presenter.error = null;
              if (state is ProvideActionArgsStateInitialize) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is ProvideActionArgsStateError) {
                _presenter.error = state.error;
                return Center(
                  child: NotificationPanelWidget(
                    notification: state.error,
                    type: NotificationPanelType.error,
                  ),
                );
              } else {
                if (state is ProvideActionArgsStateBeforeInvocation &&
                    state.initial) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ModalProgressHUD(
                  child: _buildActionCallWidget(context, state),
                  inAsyncCall: _presenter.busy,
                );
              }
            },
          )
        : Builder(
            builder: (BuildContext context) => _buildActionCallWidget(
                context, ProvideActionArgsStateNoInvocation()));
  }

  Widget _buildActionCallWidget(
      BuildContext context, ProvideActionArgsState state) {
    var child;

    bool hasRootRecordSingleLeadingField =
        _presenter.hasRootRecordSingleLeadingField();
    var editorContext = _createEditorContext(context, state);

    if (hasRootRecordSingleLeadingField) {
      child = editorContext.isAnyValueLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildActionArgumentsWidget(editorContext);
    } else {
      var children = [
        if (widget.header != null)
          Card(
            child: Padding(
              child: Text(
                widget.header,
                textAlign: TextAlign.left,
              ),
              padding: const EdgeInsets.all(10),
            ),
            shape: const BeveledRectangleBorder(),
          ),
        _buildActionArgumentsWidget(editorContext),
        _buildButtonBar(context),
      ];

      child = _presenter.isScrollable()
          ? ListView(
              shrinkWrap: true,
              children: children,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            );
    }

    return Padding(
      padding: EdgeInsets.only(top: hasRootRecordSingleLeadingField ? 0 : 10),
      child: Form(
        key: _formKey,
        child: child,
      ),
    );
  }

  Widget _buildButtonBar(BuildContext context) {
    var textStyle = getButtonTextStyle(context);

    return ButtonTheme(
      padding: EdgeInsets.zero,
      child: ButtonBar(
        children: [
          if (_presenter.callable &&
              _presenter.showCall &&
              _presenter.callLabel != null)
            TextButton(
              onPressed: () => _submit(context),
              child: Text(_presenter.callLabel.toUpperCase(), style: textStyle),
            ),
          if (_presenter.showRefresh &&
              _presenter.refreshLabel != null &&
              _presenter.hasRefreshableArgs)
            TextButton(
              onPressed: refreshArgs,
              child:
                  Text(_presenter.refreshLabel.toUpperCase(), style: textStyle),
            ),
          if (_presenter.showClear && _presenter.clearLabel != null)
            TextButton(
              onPressed: _clearArgs,
              child:
                  Text(_presenter.clearLabel.toUpperCase(), style: textStyle),
            ),
          if (_presenter.showCancel && _presenter.cancelLabel != null)
            TextButton(
              onPressed: () => _onCancel(context),
              child:
                  Text(_presenter.cancelLabel.toUpperCase(), style: textStyle),
            ),
        ],
      ),
    );
  }

  Widget _buildActionArgumentsWidget(TypeEditorContext editorContext) {
    var editor = _mainArgsGuiProvider.createEditor(editorContext);

    var argWidget = OptionalScrollContainer(
      child: editor,
      scrollable: _presenter.isScrollable(),
    );

    return _presenter.isScrollable() ||
            _presenter.hasRootRecordSingleLeadingField()
        ? argWidget
        : Expanded(child: argWidget);
  }

  TypeEditorContext _createEditorContext(
      BuildContext context, ProvideActionArgsState state) {
    return TypeEditorContext(
      '${_presenter.connectionName}-${widget.actionData.actionMeta.name}-args',
      context,
      _presenter,
      QualifiedDataType(_mainArgsGuiProvider.type),
      _presenter.actionData.argsAsRecord,
      readOnly: widget.readOnly,
      enabled: true,
      loading: state?.loading ?? [],
      rootRecordSingleLeadingField:
          ModelUtils.getRootRecordSingleLeadingFieldByAction(
                  _presenter.actionData)
              ?.qType
              ?.path,
      isRootUiContext: true,
    );
  }

  void _onCancel(BuildContext context) {
    _onClose();
    Navigator.pop(context);
  }

  Future<void> _submit(BuildContext context) async {
    doInCallbackAsync(context, () async {
      try {
        if (await saveForm()) {
          _presenter.validateArgs();

          if (_presenter.callImmediately) {
            await callActionImmediately(
              context: context,
              onBeforeCall: () => setState(() => _presenter.calling = true),
              onAfterCall: () => setState(() => _presenter.calling = false),
              actionData: _presenter.actionData,
              bloc: widget.bloc,
              showResultDialog: widget.showResultDialog,
              showNoResultDialog: widget.showResultDialogIfNoResult,
            );
          }
          // TODO Parametrize autoClose.
          Navigator.pop(context, _presenter.actionData);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar((SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        )));
      }
    });
  }

  @override
  Future<void> refresh() async {
    setState(() {});
  }

  @override
  Future<void> refreshArgs({bool showDialogOnError}) async {
    if (!mounted) {
      return;
    }

    await doInCallbackAsync(
      context,
      () async {
        setState(() {
          _presenter.calling = true;
        });
        try {
          await _presenter.refreshAllowedProvidedArgsSilently();
        } finally {
          if (mounted) {
            setState(() {
              _presenter.calling = false;
            });
          }
        }
      },
      showDialogOnError: showDialogOnError ?? (_presenter.error == null),
      logStackTrace: _presenter.error == null,
      rethrowError: false,
    );
  }

  @override
  Future<bool> saveForm() async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();

      return true;
    }

    return false;
  }

  void _clearArgs() {
    doInCallback(context, () {
      setState(() {
        _formKey = GlobalKey<FormState>();
        _presenter.clearArgs();
      });
    });
  }

  @override
  Future<void> onBeforeSubActionCall() async {
    setState(() {
      _presenter.calling = true;
    });
  }

  @override
  Future<void> onAfterSubActionCall(ActionCallState state) async {
    String error;

    try {
      if (state is ActionCallStateEnded &&
          state.resultInfo?.exception != null) {
        error = state.resultInfo?.exception.toString();
      } else if (state is ActionCallStateError) {
        error = state.error?.toString();
      }

      if (error != null) {
        await showErrorDialog(context, error);
      }

      await _presenter.refreshAllowedProvidedArgsSilently();

      // Restart the main Form to read current values of arguments to text fields!
      _formKey = GlobalKey<FormState>();
    } finally {
      setState(() {
        _presenter.calling = false;
      });
    }
  }

  Widget _resolveSubActionsWidget(BuildContext context) {
    return SubActionsWidget.forRecord(
      _createEditorContext(context, ProvideActionArgsStateNoInvocation()),
      _presenter.service.spongeService,
      tooltip: 'Context actions',
    );
  }
}
