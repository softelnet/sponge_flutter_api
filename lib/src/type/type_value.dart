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

import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/type/generic_type.dart';

abstract class BinaryValue {
  BinaryValue(this.type);

  final BinaryType type;
}

class DrawingBinaryValue extends BinaryValue {
  DrawingBinaryValue(BinaryType type) : super(type) {
    expectedWidth =
        int.tryParse(type.features[Features.BINARY_WIDTH]?.toString());
    expectedHeight =
        int.tryParse(type.features[Features.BINARY_HEIGHT]?.toString());

    Validate.isTrue(expectedWidth != null && expectedHeight != null,
        "The image must have '${Features.BINARY_WIDTH}' and '${Features.BINARY_HEIGHT}' features set");

    var strokeWidth =
        num.tryParse(type.features[Features.BINARY_STROKE_WIDTH]?.toString());
    if (strokeWidth != null) {
      strokeWidthRatio = strokeWidth / expectedWidth;
    }

    var colorFeature = type.features[Features.BINARY_COLOR];
    if (colorFeature != null) {
      color = GenericColor(int.parse('0x$colorFeature'));
    }

    var backgroundFeature = type.features[Features.BINARY_BACKGROUND];
    if (backgroundFeature != null) {
      background = GenericColor(int.parse('0x$backgroundFeature'));
    }
  }

  factory DrawingBinaryValue.scale(DrawingBinaryValue source, double ratio) {
    return DrawingBinaryValue.copyWith(
      source,
      strokes: source.strokes
          .map((stroke) => stroke
              .map((offset) => GenericOffset.scale(offset, ratio, ratio))
              .toList())
          .toList(),
      expectedWidth: (source.expectedWidth * ratio).ceil(),
      expectedHeight: (source.expectedHeight * ratio).ceil(),
      displaySize: GenericSize.scale(source.displaySize, ratio, ratio),
    );
  }

  factory DrawingBinaryValue.copyWith(
    DrawingBinaryValue source, {
    List<List<GenericOffset>> strokes,
    int expectedWidth,
    int expectedHeight,
    double strokeWidthRatio,
    GenericSize displaySize,
    GenericColor color,
    GenericColor background,
  }) {
    var value = DrawingBinaryValue(source.type);

    value.strokes = strokes ?? source.strokes;
    value.expectedWidth = expectedWidth ?? source.expectedWidth;
    value.expectedHeight = expectedHeight ?? source.expectedHeight;
    value.strokeWidthRatio = strokeWidthRatio ?? source.strokeWidthRatio;
    value.displaySize = displaySize ?? source.displaySize;
    value.color = color ?? source.color;
    value.background = background ?? source.background;

    return value;
  }

  List<List<GenericOffset>> strokes = [];
  int expectedWidth;
  int expectedHeight;
  double strokeWidthRatio = 0.1;
  GenericSize displaySize;

  GenericColor color = GenericColor.white;
  GenericColor background = GenericColor.black;
  double get aspectRatio => expectedWidth != null && expectedHeight != null
      ? expectedWidth / expectedHeight
      : 0.0;

  double get strokeDisplayWidth => displaySize.width * strokeWidthRatio;

  void clear() => strokes.clear();
}
