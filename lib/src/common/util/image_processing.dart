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

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart';

String encodeImageToPngBase64(Uint8List bytes) {
  return base64.encode(bytes);
}

Uint8List createThumbnail(Uint8List imageData, int size) {
  if (imageData == null) {
    return null;
  }

  var image = decodeImage(imageData.buffer.asUint8List());
  bool portrait = image.width <= image.height;
  return encodePng(portrait
      ? copyResize(image, height: size)
      : copyResize(image, width: size));
}
