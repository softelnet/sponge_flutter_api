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
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';

class LoginData {
  LoginData({this.username, this.password});

  String username;
  String password;
}

class LoginPage extends StatefulWidget {
  LoginPage({Key key, @required this.connectionName}) : super(key: key);

  final String connectionName;

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginData = LoginData();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  static const double PADDING = 10.0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Log in to ${widget.connectionName}'),
        ),
        body: ModalProgressHUD(child: _buildMainWidget(), inAsyncCall: _busy));
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
                        onSaved: (value) => setState(() => _loginData.username =
                            value != null && value.isNotEmpty
                                ? value.trim()
                                : null),
                        initialValue: _loginData.username,
                        validator: (value) => (value ?? '').trim().isNotEmpty
                            ? null
                            : 'The user name must not be empty',
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
                        onSaved: (value) => setState(() => _loginData.password =
                            value != null && value.isNotEmpty
                                ? value.trim()
                                : null),
                        initialValue: _loginData.password,
                        validator: (value) => (value ?? '').trim().isNotEmpty
                            ? null
                            : 'The password must not be empty',
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
                        .then((_) => Navigator.pop(context, _loginData))
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
      _formKey.currentState.save(); // Save our form now.

      final ApplicationService service =
          ApplicationProvider.of(context).service;

      service.spongeService.connection.username = _loginData.username;
      service.spongeService.connection.password = _loginData.password;

      await service.spongeService.getVersion();
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
