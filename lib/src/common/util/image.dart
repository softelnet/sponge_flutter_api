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

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart';

// class ImageBytesWithSize {
//   const ImageBytesWithSize(this.imageBytes, this.width, this.height);
//   final Uint8List imageBytes;
//   final int width, height;
// }

String encodeImageToPngBase64(Uint8List bytes) {
  return base64.encode(bytes);
  // var image = decodeImage(imageBytesWithSize.imageBytes);
  // // Resize the image if width != null.
  // // if (imageBytesWithSize.width != null) {
  // //   image =
  // //       copyResize(image, imageBytesWithSize.width, imageBytesWithSize.height ?? -1);
  // // }

  // // Encode the image to base64.
  // return base64.encode(encodePng(image));
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
