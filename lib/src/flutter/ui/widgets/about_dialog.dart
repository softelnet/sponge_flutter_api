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
import 'package:package_info/package_info.dart';

Future<void> showDefaultAboutAppDialog(
  BuildContext context, {
  @required Widget contents,
  String imageAsset,
  String applicationLegalese,
}) async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  showAboutDialog(
      context: context,
      applicationVersion: packageInfo.version,
      applicationIcon: Image.asset(
        imageAsset ?? 'assets/images/icon_small.png',
        fit: BoxFit.scaleDown,
      ),
      applicationLegalese: applicationLegalese ?? '© 2020 The Sponge Authors',
      children: <Widget>[
        contents,
      ]);
}
