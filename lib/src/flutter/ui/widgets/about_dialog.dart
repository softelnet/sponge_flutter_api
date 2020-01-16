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

Future<void> showAboutAppDialog(BuildContext context) async {
  final ThemeData themeData = Theme.of(context);
  final TextStyle headerTextStyle =
      themeData.textTheme.body2.apply(fontWeightDelta: 2);
  final TextStyle aboutTextStyle = themeData.textTheme.body2;
  final TextStyle linkStyle =
      themeData.textTheme.body2.copyWith(color: themeData.accentColor);
  final TextStyle noteTextStyle =
      themeData.textTheme.body2.apply(color: getSecondaryColor(context));

  await showDefaultAboutAppDialog(
    context,
    contents: RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        children: <TextSpan>[
          TextSpan(
            style: headerTextStyle,
            text:
                '\n\nSponge Control is a generic GUI client to Sponge REST API services. '
                'It allows users to call remote Sponge actions.',
          ),
          TextSpan(
              style: aboutTextStyle,
              text:
                  '\n\nSponge is an open-source action and event processing system. '
                  'The supported Sponge server versions are ${SpongeClientConstants.SUPPORTED_SPONGE_VERSION_MAJOR_MINOR}.x.'),
          TextSpan(
            style: aboutTextStyle,
            text: '\n\nFor more information please visit the ',
          ),
          LinkTextSpan(
            style: linkStyle,
            url: 'https://sponge.openksavi.org/mobile',
            text: 'Sponge Control',
          ),
          TextSpan(
            style: aboutTextStyle,
            text: ' home page and the ',
          ),
          LinkTextSpan(
            style: linkStyle,
            url: 'https://sponge.openksavi.org',
            text: 'Sponge',
          ),
          TextSpan(
            style: aboutTextStyle,
            text:
                ' project home page.\n\nTo see the source code of this app, please visit the Sponge Control ',
          ),
          LinkTextSpan(
            style: linkStyle,
            url: 'https://github.com/softelnet/sponge_flutter_client',
            text: 'GitHub repo',
          ),
          TextSpan(
            style: aboutTextStyle,
            text: '.',
          ),
          TextSpan(
              style: noteTextStyle,
              text:
                  '\n\nThe current version is in alpha phase and supports only a limited set of data types and type features.'
                  ''),
        ],
      ),
    ),
  );
}

Future<void> showDefaultAboutAppDialog(BuildContext context,
    {@required Widget contents}) async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  showAboutDialog(
      context: context,
      applicationVersion: packageInfo.version,
      applicationIcon: Image.asset(
        'assets/images/icon_small.png',
        fit: BoxFit.scaleDown,
      ),
      applicationLegalese: '© 2020 The Sponge Authors',
      children: <Widget>[
        contents,
      ]);
}
