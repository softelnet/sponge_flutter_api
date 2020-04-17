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
  static const double PADDING = 10.0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    _presenter ??= LoginPresenter(
      ApplicationProvider.of(context).service,
      LoginViewModel(widget.connectionName),
      this,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_presenter.title),
      ),
      body: ModalProgressHUD(
        child: _buildMainWidget(),
        inAsyncCall: _busy,
      ),
    );
  }

  Widget _buildMainWidget() {
    return Builder(
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
                    Padding(
                      padding: const EdgeInsets.only(
                          left: PADDING, right: PADDING, top: 2.0),
                      child: TextFormField(
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          border: const UnderlineInputBorder(),
                          labelText: 'User name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        onSaved: (value) => setState(() => _presenter.username =
                            CommonUtils.normalizeString(value)),
                        initialValue: _presenter.username,
                        validator: (value) => (value?.trim()?.isEmpty ?? true)
                            ? 'The user name must not be empty'
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: PADDING, right: PADDING, top: 2.0),
                      child: TextFormField(
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          border: const UnderlineInputBorder(),
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.verified_user),
                        ),
                        onSaved: (value) => setState(() => _presenter.password =
                            CommonUtils.normalizeString(value)),
                        initialValue: _presenter.password,
                        validator: (value) => (value?.trim()?.isEmpty ?? true)
                            ? 'The password must not be empty'
                            : null,
                        obscureText: true,
                      ),
                    ),
                  ],
                ),
              ),
              ButtonBar(
                children: [
                  RaisedButton(
                    onPressed: () => _logIn(context)
                        .then(
                            (_) => Navigator.pop(context, _presenter.loginData))
                        .catchError((e) => handleError(context, e)),
                    child: Text('LOG IN'),
                  ),
                  RaisedButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text('CANCEL'),
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
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();

      setState(() => _busy = true);
      try {
        await _presenter.logIn();
      } catch (e) {
        await handleError(context, e);
      } finally {
        setState(() => _busy = false);
      }
    }
  }
}

Future<LoginData> showLoginPage(
    BuildContext context, String connectionName) async {
  return await Navigator.push(
      context,
      MaterialPageRoute<LoginData>(
        builder: (BuildContext context) =>
            LoginPage(connectionName: connectionName),
        fullscreenDialog: true,
      ));
}
