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
import 'package:sponge_flutter_api/sponge_flutter_api.dart';

Future<void> showErrorDialog(BuildContext context, String message) async {
  await showModalDialog(context, 'Error', Text(message));
}

Future<void> showWarningDialog(BuildContext context, String message) async {
  await showModalDialog(context, 'Warning', Text(message));
}

Future<void> showModalDialog(BuildContext context, String title, Widget child,
    {String closeButtonLabel = 'OK'}) async {
  await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                child,
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(closeButtonLabel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      });
}

Future<bool> showConfirmationDialog(
    BuildContext context, String message) async {
  bool result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('YES'),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop(true);
              },
            ),
            TextButton(
              child: const Text('NO'),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop(false);
              },
            ),
          ],
        );
      });
  return result ?? false;
}

Future<bool> showAppExitConfirmationDialog(BuildContext context) async {
  if (ApplicationProvider.of(context).service.settings.exitConfirmation) {
    return await showConfirmationDialog(
        context, 'Are you sure you want to exit the app?');
  }

  return true;
}
