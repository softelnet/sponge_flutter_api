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

  TextEditingController _nameController;
  TextEditingController _urlController;
  TextEditingController _networkController;
  TextEditingController _usernameController;
  TextEditingController _passwordController;

  @override
  void dispose() {
    _presenter.unbound();

    _nameController?.dispose();
    _urlController?.dispose();
    _networkController?.dispose();
    _usernameController?.dispose();
    _passwordController?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _presenter ??= ConnectionEditPresenter(
      ApplicationProvider.of(context).service,
      ConnectionEditViewModel(widget.originalConnection),
      this,
    );

    _nameController ??= TextEditingController(text: _presenter.name)
      ..addListener(() {
        _presenter.name = _nameController.text;
      });

    _urlController ??= TextEditingController(text: _presenter.url)
      ..addListener(() {
        _presenter.url = _urlController.text;
      });

    _networkController ??= TextEditingController(text: _presenter.network)
      ..addListener(() {
        _presenter.network = _networkController.text;
      });

    _usernameController ??= TextEditingController(text: _presenter.username)
      ..addListener(() {
        _presenter.username = _usernameController.text;
      });

    _passwordController ??= TextEditingController(text: _presenter.password)
      ..addListener(() {
        _presenter.password = _passwordController.text;
      });

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
                      icon: const Icon(Icons.bookmark),
                      onSaved: (String value) {
                        setState(() => _presenter.name = value);
                      },
                      controller: _nameController,
                      validator: _presenter.validateName,
                      autofocus: !_presenter.editing,
                    ),
                    _buildConnectionFieldWidget(
                      key: Key('address'),
                      keyboardType: TextInputType.text,
                      labelText: 'Sponge address *',
                      icon: const Icon(Icons.computer),
                      onSaved: (String value) {
                        setState(() => _presenter.url = value);
                      },
                      controller: _urlController,
                      validator: _presenter.validateUrl,
                    ),
                    _buildConnectionFieldWidget(
                      key: Key('network'),
                      keyboardType: TextInputType.text,
                      labelText: 'Network',
                      icon: const Icon(Icons.wifi),
                      onSaved: (String value) {
                        setState(() => _presenter.network = value);
                      },
                      controller: _networkController,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: PADDING),
                      child: Row(
                        children: <Widget>[
                          const Text('Anonymous'),
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
                      labelText: 'Username',
                      icon: const Icon(Icons.person),
                      onSaved: (String value) {
                        setState(() => _presenter.username = value);
                      },
                      controller: _usernameController,
                      enabled: !_presenter.anonymous,
                      validator: _presenter.validateUsername,
                    ),
                    _buildConnectionFieldWidget(
                      key: Key('password'),
                      keyboardType: TextInputType.text,
                      labelText: 'Password',
                      icon: const Icon(Icons.verified_user),
                      onSaved: (String value) => _presenter.password = value,
                      controller: _passwordController,
                      obscureText: true,
                      enabled: !_presenter.anonymous,
                      validator: _presenter.validatePassword,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: PADDING),
                      child: Row(
                        children: <Widget>[
                          const Text('Save password'),
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
                          .catchError((e) => handleConnectionError(context, e)),
                      child: Text('OK', style: getButtonTextStyle(context)),
                    ),
                    FlatButton(
                      onPressed: () => _verifyConnection(context)
                          .catchError((e) => handleConnectionError(context, e)),
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
    TextEditingController controller,
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
          suffixIcon: createClearableTextFieldSuffixIcon(context, controller),
        ),
        onSaved: onSaved,
        controller: controller,
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

      var snackController = Scaffold.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verifying the connection...'),
          duration: Duration(hours: 1),
        ),
      );

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
