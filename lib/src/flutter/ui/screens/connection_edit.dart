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
import 'package:logging/logging.dart';
import 'package:modal_progress_hud/modal_progress_hud.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/application_constants.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/ui/connection_edit_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/state_container.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';

class ConnectionEditWidget extends StatefulWidget {
  ConnectionEditWidget({Key key, this.originalConnection}) : super(key: key);

  final SpongeConnection originalConnection;

  @override
  createState() => _ConnectionEditWidgetState();
}

class _ConnectionEditWidgetState extends State<ConnectionEditWidget>
    implements ConnectionEditView {
  static final Logger _logger = Logger('ConnectionEditWidget');
  ConnectionEditPresenter _presenter;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  static const double PADDING = 10.0;

  @override
  void initState() {
    super.initState();

    _presenter = ConnectionEditPresenter(
        ConnectionEditViewModel(widget.originalConnection), this);
  }

  @override
  Widget build(BuildContext context) {
    _presenter..setService(StateContainer.of(context).service);

    return Scaffold(
      appBar: AppBar(
        title: Text(_presenter.editing
            ? 'Edit connection ${_presenter.originalConnection.name}'
            : 'Create a new connection'),
      ),
      body: SafeArea(
        child: ModalProgressHUD(
          child: _buildMainWidget(),
          inAsyncCall: _presenter.busy,
        ),
      ),
    );
  }

  Widget _buildMainWidget() {
    return Builder(
      // Create an inner BuildContext so that the other methods
      // can refer to the Scaffold with Scaffold.of().
      builder: (BuildContext context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: PADDING),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Form(
                key: this._formKey,
                child: Column(
                  children: <Widget>[
                    _buildConnectionFieldWidget(
                      key: Key('name'),
                      keyboardType: TextInputType.text,
                      labelText: 'Connection name *',
                      icon: Icon(Icons.bookmark),
                      onSaved: (String value) {
                        setState(() => _presenter.name = value);
                      },
                      initialValue: _presenter.name,
                      validator: _presenter.validateName,
                    ),
                    _buildConnectionFieldWidget(
                      key: Key('address'),
                      keyboardType: TextInputType.text,
                      labelText: 'Sponge address *',
                      icon: Icon(Icons.computer),
                      onSaved: (String value) {
                        setState(() => _presenter.url = value);
                      },
                      initialValue:
                          _presenter.url ?? ApplicationConstants.URL_TEMPLATE,
                      validator: _presenter.validateUrl,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: PADDING),
                      child: Row(
                        children: <Widget>[
                          Text('Anonymous'),
                          Checkbox(
                            key: Key('anonymous'),
                            value: _presenter.anonymous,
                            onChanged: (bool value) {
                              setState(() {
                                _presenter.anonymous = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    _buildConnectionFieldWidget(
                      key: Key('username'),
                      keyboardType: TextInputType.text,
                      labelText: 'User name',
                      icon: Icon(Icons.person),
                      onSaved: (String value) {
                        setState(() => _presenter.username = value);
                      },
                      initialValue: _presenter.username,
                      enabled: !_presenter.anonymous,
                      validator: _presenter.validateUsername,
                    ),
                    _buildConnectionFieldWidget(
                      key: Key('password'),
                      keyboardType: TextInputType.text,
                      labelText: 'Password',
                      icon: Icon(Icons.verified_user),
                      onSaved: (String value) => _presenter.password = value,
                      initialValue: _presenter.password,
                      obscureText: true,
                      enabled: !_presenter.anonymous,
                      validator: _presenter.validatePassword,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: PADDING),
                      child: Row(
                        children: <Widget>[
                          Text('Save password'),
                          Checkbox(
                            key: Key('save-password'),
                            value: _presenter.savePassword,
                            onChanged: (bool value) {
                              setState(() {
                                _presenter.savePassword = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ButtonTheme(
                textTheme: ButtonTextTheme.accent,
                padding: EdgeInsets.zero,
                child: ButtonBar(
                  children: [
                    FlatButton(
                      onPressed: () => _saveConnection(context)
                          .catchError((e) => handleError(context, e)),
                      child: Text('OK', style: getButtonTextStyle(context)),
                    ),
                    FlatButton(
                      onPressed: () => _testConnection(context)
                          .catchError((e) => handleError(context, e)),
                      child: Text('VERIFY', style: getButtonTextStyle(context)),
                    ),
                    FlatButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: Text('CANCEL', style: getButtonTextStyle(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionFieldWidget({
    Key key,
    TextInputType keyboardType,
    String labelText,
    FormFieldSetter<String> onSaved,
    String initialValue,
    FormFieldValidator<String> validator,
    Widget icon,
    bool obscureText = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: PADDING, right: PADDING, top: 2.0),
      child: TextFormField(
        key: key,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: const UnderlineInputBorder(),
          //filled: true,
          labelText: labelText,
          //prefixIcon: icon,
        ),
        onSaved: onSaved,
        //onFieldSubmitted: (String value) => _setArg(index, value),
        initialValue: initialValue,
        validator: validator,
        obscureText: obscureText,
        enabled: enabled,
      ),
    );
  }

  Future<void> _testConnection(BuildContext context) async {
    if (this._formKey.currentState.validate()) {
      _formKey.currentState.save();

      var snackController = Scaffold.of(context).showSnackBar(SnackBar(
          content: Text('Verifying the connection...'),
          duration: Duration(hours: 1)));

      try {
        var version = await _presenter.testConnection();
        await verifyServerVersion(context, version);
      } finally {
        try {
          snackController.close();
        } catch (e) {
          _logger.fine('Error closing the snack bar: $e');
        }
      }
    }
  }

  Future<void> _saveConnection(BuildContext context) async {
    if (this._formKey.currentState.validate()) {
      _formKey.currentState.save();

      Navigator.pop(context, _presenter.connection);
    }
  }

  Future<void> verifyServerVersion(BuildContext context, String version) async {
    if (SpongeUtils.isServerVersionCompatible(version)) {
      await showModalDialog(
          context, 'Information', Text('The connection is OK.'));
    } else {
      await showModalDialog(
          context,
          'Warning',
          Text(
              'The connection is OK but the Sponge server version $version doesn\'t match '
              'the supported major.minor version ${SpongeClientConstants.SUPPORTED_SPONGE_VERSION_MAJOR_MINOR}.'));
    }
  }
}
