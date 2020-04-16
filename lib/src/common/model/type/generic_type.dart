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

class GenericOffset {
  GenericOffset(this.x, this.y);
  double x, y;

  factory GenericOffset.scale(
          GenericOffset source, double scaleX, double scaleY) =>
      GenericOffset(source.x, source.y)..scale(scaleX, scaleY);

  void scale(double scaleX, double scaleY) {
    x *= scaleX;
    y *= scaleY;
  }
}

class GenericSize {
  GenericSize(this.width, this.height);
  double width, height;

  factory GenericSize.scale(GenericSize source, double scaleX, double scaleY) =>
      GenericSize(source.width, source.height)..scale(scaleX, scaleY);

  void scale(double scaleX, double scaleY) {
    width *= scaleX;
    height *= scaleY;
  }
}

class GenericColor {
  // Only solid colors are supported.
  const GenericColor(int value) : _value = value | 0xFF000000;
  final int _value;
  int get value => _value;

  factory GenericColor.fromHexString(String colorRgbHex) =>
      GenericColor(int.parse('0x$colorRgbHex'));

  static const GenericColor white = GenericColor(0xFFFFFFFF);
  static const GenericColor black = GenericColor(0xFF000000);

  String _toHexString(int v) =>
      v.toRadixString(16).toUpperCase().padLeft(2, '0');

  int get red => (0x00FF0000 & _value) >> 16;

  int get green => (0x0000FF00 & _value) >> 8;

  int get blue => (0x000000FF & _value) >> 0;

  String toHexString() =>
      _toHexString(red) + _toHexString(green) + _toHexString(blue);
}
