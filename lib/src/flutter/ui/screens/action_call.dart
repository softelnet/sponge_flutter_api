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
import 'package:modal_progress_hud/modal_progress_hud.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_bloc.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/ui/action_call_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/state_container.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/action_result.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/unit_type_gui_providers.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/edit_widgets.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/error_widgets.dart';
import 'package:sponge_flutter_api/src/util/utils.dart';

class ActionCallWidget extends StatefulWidget {
  ActionCallWidget({
    Key key,
    @required this.actionData,
    this.readOnly = false,
    this.callImmediately = false,
    this.showResultDialog = true,
    this.showResultDialogIfNoResult = true,
    @required this.bloc,
    this.header,
  }) : super(key: key);

  final ActionData actionData;
  final bool readOnly;
  final bool callImmediately;
  final bool showResultDialog;
  final bool showResultDialogIfNoResult;
  // TODO Refactor to the presenter.
  final ActionCallBloc bloc;
  final String header;

  @override
  createState() => _ActionCallWidgetState();
}

class _ActionCallWidgetState extends State<ActionCallWidget>
    implements ActionCallView {
  ActionCallPresenter _presenter;
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  RecordTypeGuiProvider _mainArgsGuiProvider;

  @override
  void dispose() {
    _presenter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var service = StateContainer.of(context).service;

    // Use a copy of the action data.
    _presenter ??=
        ActionCallPresenter(ActionCallViewModel(widget.actionData.copy()), this)
          ..setService(service)
          ..init();

    _presenter.ensureRunning();

    _mainArgsGuiProvider ??=
        service.getTypeGuiProvider(widget.actionData.argsAsRecordType);

    // // Populate the providers cache. The providers defined in the MobileAcionData are not used here.
    // _typeGuiProvidersCache ??= List.generate(_presenter.argTypes?.length ?? 0,
    //     (index) => service.getTypeGuiProvider(_presenter.argTypes[index].type));

    return WillPopScope(
      child: SwipePopDetector(
        onSwipe: () => _onCancel(context),
        child: Scaffold(
          appBar: AppBar(title: Text('${_presenter.actionLabel}')),
          body: SafeArea(
            child: ModalProgressHUD(
              child: _presenter.hasProvidedArgs
                  ? StreamBuilder<bool>(
                      stream: _presenter.provideArgs(),
                      builder: (context, snapshot) {
                        _presenter.error = null;
                        if (snapshot.hasData) {
                          return _buildWidget(context);
                        } else if (snapshot.hasError) {
                          _presenter.error = snapshot.error;
                          return Center(
                              child: ErrorPanelWidget(error: snapshot.error));
                        }
                        return Center(child: CircularProgressIndicator());
                      },
                    )
                  : Builder(
                      builder: (BuildContext context) => _buildWidget(context)),
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

  void _onClose() {
    widget.actionData.rebind(_presenter.actionData);

    if (_presenter.anyArgSavedOrUpdated) {
      if (widget.callImmediately) {
        widget.actionData.resultInfo = _presenter.actionData.resultInfo;
      } else {
        widget.actionData.resultInfo = null;
      }
    }
  }

  Widget _buildWidget(BuildContext context) {
    var textStyle = getButtonTextStyle(context);
    var buttonBar = ButtonTheme(
      padding: EdgeInsets.zero,
      child: ButtonBar(
        children: [
          if (_presenter.callable &&
              _presenter.showCall &&
              _presenter.callLabel != null)
            FlatButton(
              onPressed: () => _submit(context),
              child: Text(_presenter.callLabel.toUpperCase(), style: textStyle),
            ),
          if (_presenter.showRefresh &&
              _presenter.refreshLabel != null &&
              _presenter.hasRefreshableArgs)
            FlatButton(
              onPressed: refreshArgs,
              child:
                  Text(_presenter.refreshLabel.toUpperCase(), style: textStyle),
            ),
          if (_presenter.showClear && _presenter.clearLabel != null)
            FlatButton(
              onPressed: _clearArgs,
              child:
                  Text(_presenter.clearLabel.toUpperCase(), style: textStyle),
            ),
          if (_presenter.showCancel && _presenter.cancelLabel != null)
            FlatButton(
              onPressed: () => _onCancel(context),
              child:
                  Text(_presenter.cancelLabel.toUpperCase(), style: textStyle),
            ),
        ],
      ),
    );

    var children = [
      if (widget.header != null)
        Card(
          child: Padding(
            child: Text(
              widget.header,
              textAlign: TextAlign.left,
            ),
            padding: EdgeInsets.all(10),
          ),
          shape: BeveledRectangleBorder(),
        ),
      _buildActionArgumentsWidget(context),
      buttonBar,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Form(
        key: this._formKey,
        child: _presenter.isScrollable()
            ? ListView(
                shrinkWrap: true,
                children: children,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
      ),
    );
  }

  Widget _buildActionArgumentsWidget(BuildContext context) {
    var argWidget = OptionalScrollContainer(
      child: _mainArgsGuiProvider.createEditor(
        TypeEditorContext(
          '${_presenter.connectionName}-${widget.actionData.actionMeta.name}-args',
          context,
          _presenter,
          QualifiedDataType(null, _mainArgsGuiProvider.type),
          _presenter.actionData.argsAsRecord,
          readOnly: widget.readOnly,
          enabled: true,
        ),
      ),
      scrollable: _presenter.isScrollable(),
    );

    return _presenter.isScrollable() ? argWidget : Expanded(child: argWidget);
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

          if (widget.callImmediately) {
            await callActionImmediately(
              context: context,
              onBeforeCall: () => setState(() => _presenter.busy = true),
              onAfterCall: () => setState(() => _presenter.busy = false),
              actionData: _presenter.actionData,
              bloc: widget.bloc,
              showResultDialog: widget.showResultDialog,
              showNoResultDialog: widget.showResultDialogIfNoResult,
            );
          }
          // TODO Parametrize autoClose
          Navigator.pop(context, _presenter.actionData);
        }
      } catch (e) {
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ));
      }
    });
  }

  @override
  Future<void> refreshArgs({bool modal = true}) async {
    if (!mounted) {
      return;
    }

    await doInCallbackAsync(
      context,
      () async {
        if (modal) {
          setState(() {
            _presenter.busy = true;
          });
        }
        try {
          await _refreshArgs();
        } finally {
          if (mounted) {
            setState(() {
              _presenter.busy = false;
            });
          }
        }
      },
      showDialogOnError: _presenter.error == null,
      logStackTrace: _presenter.error == null,
      rethrowError: false,
    );
  }

  Future<void> _refreshArgs() async {
    await _presenter.refreshAllowedProvidedArgs();
  }

  Future<bool> saveForm() async {
    if (this._formKey.currentState.validate()) {
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

  void refresh() => setState(() {});

  @override
  Future<void> onBeforeSubActionCall() async {
    setState(() {
      _presenter.busy = true;
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

      await _refreshArgs();
    } finally {
      setState(() {
        _presenter.busy = false;
      });
    }
  }
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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => bloc.state.listen((state) {
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
        title: Text(getActionMetaDisplayLabel(actionData.actionMeta)),
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
            child: Text('CLOSE'),
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

Future<void> callActionImmediately({
  @required BuildContext context,
  void onBeforeCall(),
  void onAfterCall(),
  @required ActionData actionData,
  @required ActionCallBloc bloc,
  @required bool showResultDialog,
  @required bool showNoResultDialog,
}) async {
  final service = StateContainer.of(context).service;
  var resultInfo;

  if (onBeforeCall != null) {
    onBeforeCall();
  }

  try {
    // TODO Save args is always false in this case!
    // BLoC is not used here.
    resultInfo = await service.spongeService.callAction(actionData.actionMeta,
        args: actionData.args, saveArgsAndResult: false);
  } finally {
    if (onAfterCall != null) {
      onAfterCall();
    }
  }
  actionData.resultInfo = resultInfo;
  if (!(actionData.actionMeta.result is VoidType &&
          actionData.actionMeta.result.label == null) ||
      showNoResultDialog) {
    // widget.bloc.onActionCall.add(_presenter.actionData.args);
    // await widget.bloc.state
    //     .any((_) => true); // firstWhere((state) => state.isFinal);

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
  var service = StateContainer.of(context).service;
  if (await service.spongeService.isActionActive(actionData.actionMeta.name)) {
    return await Navigator.push(
        context, MaterialPageRoute<ActionData>(builder: builder));
  } else {
    await showErrorDialog(context,
        'Action \'${actionData.actionMeta.label ?? actionData.actionMeta.name}\' is inactive');
    return null;
  }
}
