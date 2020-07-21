// Copyright 2020 The Sponge authors.
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

import 'package:package_info/package_info.dart';

typedef VoidFutureOrCallback = FutureOr<void> Function();

class CommonUtils {
  static String normalizeString(String value) {
    value = value?.trim();

    return (value?.isEmpty ?? true) ? null : value;
  }

  static bool isNetworkError(dynamic error) =>
      // It's important not to use the SocketException class directly because it will impact the supported platforms.
      // The https://pub.dev/packages/io doesn't support web.
      error?.runtimeType?.toString() == 'SocketException';

  static Future<String> getPackageVersion() async {
    var version = (await PackageInfo.fromPlatform()).version;

    return '$version (alpha)';
  }
}
