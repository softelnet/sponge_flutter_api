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

import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:sponge_flutter_api/src/common/model/type/type_value.dart';
import 'package:sponge_flutter_api/src/common/util/image.dart';
import 'package:sponge_flutter_api/src/external/painter.dart';
import 'package:sponge_flutter_api/src/flutter/compatibility/compatibility_flutter.dart';

/// Converts by drawing using the displaySize if `width` and `height` not set.
Future<Uint8List> convertImageToPng(DrawingBinaryValue binaryValue,
    {int width, int height}) async {
  if (binaryValue == null || binaryValue.displaySize == null) {
    return null;
  }

  if (width != null || height != null) {
    double ratio = width != null
        ? width / binaryValue.displaySize.width.toInt()
        : height / binaryValue.displaySize.height.toInt();
    binaryValue = DrawingBinaryValue.scale(binaryValue, ratio);
  }

  var recorder = PictureRecorder();
  var size = convertFromSize(binaryValue.displaySize);
  var canvas = Canvas(recorder, Offset.zero & size);

  // Paint the drawing in the canvas that will be recorderd to the image.
  var painterController = PainterController()
    ..drawColor = convertFromColor(binaryValue.color)
    ..backgroundColor = convertFromColor(binaryValue.background)
    ..addStrokes(convertFromStrokes(binaryValue.strokes));

  painterController.globalThickness = binaryValue.strokeDisplayWidth;

  painterController.draw(canvas, size);

  var p = recorder.endRecording();
  var pictureImage = await p.toImage(binaryValue.displaySize.width.toInt(),
      binaryValue.displaySize.height.toInt());
  var pngBytes = await pictureImage.toByteData(format: ImageByteFormat.png);

  return pngBytes.buffer.asUint8List();
}

Future<String> convertImageToPngBase64(
    DrawingBinaryValue binaryValue, int width,
    [int height]) async {
  var bytes =
      await convertImageToPng(binaryValue, width: width, height: height);

  // Run in a separate Isolate to prevent UI lags.
  return await compute(encodeImageToPngBase64,
      bytes); //ImageBytesWithSize(bytes, width, height));
}
