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
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/flutter/state_container.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';

class AdministrationWidget extends StatelessWidget {
  AdministrationWidget({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sponge administration'),
      ),
      body: Builder(
        builder: (BuildContext context) {
          return Center(
            child: RaisedButton(
              child: Text('RELOAD SPONGE'),
              onPressed: () {
                _reloadSponge(context).then((result) {
                  Scaffold.of(context).showSnackBar(SnackBar(
                    content: Text('Sponge knowledge bases reloaded'),
                  ));
                }).catchError((e) {
                  handleError(context, e);
                });
              },
            ),
          );
        },
      ),
    );
  }

  Future<ReloadResponse> _reloadSponge(BuildContext context) async =>
      await StateContainer.of(context).service.spongeService.reload();
}
