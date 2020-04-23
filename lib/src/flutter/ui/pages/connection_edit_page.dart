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
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/sponge_service_constants.dart';
import 'package:sponge_flutter_api/src/common/ui/pages/connection_edit_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';

class ConnectionEditPage extends StatefulWidget {
  ConnectionEditPage({Key key, this.originalConnection}) : super(key: key);

  final SpongeConnection originalConnection;

  @override
  _ConnectionEditPageState createState() => _ConnectionEditPageState();
}

class _ConnectionEditPageState extends State<ConnectionEditPage>
    implements ConnectionEditView {
  static final Logger _logger = Logger('ConnectionEditWidget');
  ConnectionEditPresenter _presenter;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  static const double PADDING = 10.0;

  @override
  void dispose() {
    _presenter.unbound();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _presenter ??= ConnectionEditPresenter(
      ApplicationProvider.of(context).service,
      ConnectionEditViewModel(widget.originalConnection),
      this,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _presenter.editing
              ? 'Connection: ${_presenter.originalConnection.name}'
              : 'Create a new connection',
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
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
                key: _formKey,
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
                      autofocus: !_presenter.editing,
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
                          _presenter.url ?? SpongeServiceConstants.URL_TEMPLATE,
                      validator: _presenter.validateUrl,
                    ),
                    _buildConnectionFieldWidget(
                      key: Key('network'),
                      keyboardType: TextInputType.text,
                      labelText: 'Network',
                      icon: Icon(Icons.wifi),
                      onSaved: (String value) {
                        setState(() => _presenter.network = value);
                      },
                      initialValue: _presenter.network,
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
                      onPressed: () => _verifyConnection(context)
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
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: PADDING, right: PADDING, top: 2.0),
      child: TextFormField(
        key: key,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: const UnderlineInputBorder(),
          labelText: labelText,
        ),
        onSaved: onSaved,
        initialValue: initialValue,
        validator: validator,
        obscureText: obscureText,
        enabled: enabled,
        autofocus: autofocus,
      ),
    );
  }

  Future<void> _verifyConnection(BuildContext context) async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();

      var snackController = Scaffold.of(context).showSnackBar(SnackBar(
          content: Text('Verifying the connection...'),
          duration: Duration(hours: 1)));

      try {
        var version = await _presenter.verifyConnection();

        if (_presenter.isBound) {
          await verifyServerVersion(context, version);
        }
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
    if (_formKey.currentState.validate()) {
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
        Text('The Sponge server version $version is incompatible '
            'with the supported versions ${SpongeClientConstants.SUPPORTED_SPONGE_VERSION_MAJOR_MINOR}.*'),
      );
    }
  }
}
