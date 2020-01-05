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

// This code is based on: https://github.com/flutter/flutter/blob/master/examples/flutter_gallery/lib/gallery/about.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';

Future showAboutAppDialog(BuildContext context) async {
  final ThemeData themeData = Theme.of(context);
  final TextStyle aboutTextStyle = themeData.textTheme.body2;
  final TextStyle linkStyle =
      themeData.textTheme.body2.copyWith(color: themeData.accentColor);
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  showAboutDialog(
      context: context,
      applicationVersion: packageInfo.version,
      applicationIcon: Image.asset(
        'assets/images/icon.png',
        fit: BoxFit.scaleDown,
        width: 100.0,
      ),
      applicationLegalese: '© 2020 The Sponge Authors',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 24.0),
          child: RichText(
            text: TextSpan(
              children: <TextSpan>[
                TextSpan(
                  style: aboutTextStyle,
                  text:
                      'Sponge is an open-source action and event processing system. '
                      'This application is a simple, generic GUI client to the Sponge REST API service. '
                      'It allows users to call remote Sponge actions.'
                      '\n\nThe supported Sponge server versions are ${SpongeClientConstants.SUPPORTED_SPONGE_VERSION_MAJOR_MINOR}.x.',
                ),
                TextSpan(
                  style: aboutTextStyle,
                  text: '\n\nFor more information please visit the ',
                ),
                LinkTextSpan(
                  style: linkStyle,
                  url: 'https://sponge.openksavi.org/mobile',
                  text: 'Sponge mobile client application',
                ),
                TextSpan(
                  style: aboutTextStyle,
                  text: ' home page and the ',
                ),
                LinkTextSpan(
                  style: linkStyle,
                  url: 'https://sponge.openksavi.org',
                  text: 'Sponge project',
                ),
                TextSpan(
                  style: aboutTextStyle,
                  text:
                      ' home page.\n\nTo see the source code of this app, please visit the ',
                ),
                LinkTextSpan(
                  style: linkStyle,
                  url: 'https://github.com/softelnet/sponge_flutter_client',
                  text: 'Sponge flutter client github repo',
                ),
                TextSpan(
                  style: aboutTextStyle,
                  text: '.',
                ),
                TextSpan(
                    style: aboutTextStyle,
                    text:
                        '\n\nThe current version supports only limited set of data types and type features.'
                        ''),
              ],
            ),
          ),
        ),
      ]);
}
