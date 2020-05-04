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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:modal_progress_hud/modal_progress_hud.dart';
import 'package:sponge_flutter_api/src/common/ui/pages/login_mvp.dart';
import 'package:sponge_flutter_api/src/common/util/common_utils.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';

// TODO Test this component.
class LoginPage extends StatefulWidget {
  LoginPage({Key key, @required this.connectionName}) : super(key: key);

  final String connectionName;

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> implements LoginView {
  LoginPresenter _presenter;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  static const double margin = 10;
  static const padding = EdgeInsets.only(left: margin, right: margin, top: 2);
  bool _busy = false;

  TextEditingController _usernameController;
  TextEditingController _passwordController;

  @override
  void dispose() {
    super.dispose();

    _usernameController?.dispose();
    _passwordController?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _presenter ??= LoginPresenter(
      ApplicationProvider.of(context).service,
      LoginViewModel(widget.connectionName),
      this,
    );

    _usernameController ??= TextEditingController(text: _presenter.username)
      ..addListener(() {
        _presenter.username =
            CommonUtils.normalizeString(_usernameController.text);
      });

    _passwordController ??= TextEditingController(text: _presenter.password)
      ..addListener(() {
        _presenter.password =
            CommonUtils.normalizeString(_passwordController.text);
      });

    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_presenter.title),
        ),
        body: ModalProgressHUD(
          child: _buildMainWidget(),
          inAsyncCall: _busy,
        ),
      ),
      onWillPop: () async {
        _onClose();
        return true;
      },
    );
  }

  Widget _buildMainWidget() {
    return Builder(
      builder: (BuildContext context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: margin),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: padding,
                      child: TextFormField(
                        key: Key('username'),
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          border: const UnderlineInputBorder(),
                          labelText: 'Username',
                          //prefixIcon: Icon(Icons.person),
                          suffixIcon: createClearableTextFieldSuffixIcon(
                              context, _usernameController),
                        ),
                        controller: _usernameController,
                        onSaved: (value) => setState(() => _presenter.username =
                            CommonUtils.normalizeString(value)),
                        validator: (value) => (value?.trim()?.isEmpty ?? true)
                            ? 'The username must not be empty'
                            : null,
                      ),
                    ),
                    Padding(
                      padding: padding,
                      child: TextFormField(
                        key: Key('password'),
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          border: const UnderlineInputBorder(),
                          labelText: 'Password',
                          suffixIcon: createClearableTextFieldSuffixIcon(
                              context, _passwordController),
                          //prefixIcon: Icon(Icons.verified_user),
                        ),
                        controller: _passwordController,
                        onSaved: (value) => setState(() => _presenter.password =
                            CommonUtils.normalizeString(value)),
                        validator: (value) => (value?.trim()?.isEmpty ?? true)
                            ? 'The password must not be empty'
                            : null,
                        obscureText: true,
                      ),
                    ),
                    Padding(
                      padding: padding,
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
              ButtonBar(
                children: [
                  FlatButton(
                    onPressed: () async => await _logIn(context),
                    child: Text('LOG IN', style: getButtonTextStyle(context)),
                  ),
                  FlatButton(
                    onPressed: () {
                      _onClose();
                      Navigator.pop(context, null);
                    },
                    child: Text('CANCEL', style: getButtonTextStyle(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logIn(BuildContext context) async {
    try {
      if (_formKey.currentState.validate()) {
        _formKey.currentState.save();

        setState(() => _busy = true);
        try {
          await _presenter.logIn();
        } finally {
          setState(() => _busy = false);
        }

        Navigator.pop(context, _presenter.loginData);
      }
    } catch (e) {
      await handleError(context, e);
    }
  }

  void _onClose() {
    _presenter.onCancel();
  }
}
