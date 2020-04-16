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

import 'dart:ui';

import 'package:sponge_flutter_api/src/common/model/type/generic_type.dart';

Offset convertFromOffset(GenericOffset offset) =>
    offset != null ? Offset(offset.x, offset.y) : null;
GenericOffset convertToOffset(Offset offset) =>
    offset != null ? GenericOffset(offset.dx, offset.dy) : null;

Size convertFromSize(GenericSize size) =>
    size != null ? Size(size.width, size.height) : null;
GenericSize convertToSize(Size size) =>
    size != null ? GenericSize(size.width, size.height) : null;

Color convertFromColor(GenericColor color) =>
    color != null ? Color(color.value) : null;
GenericColor convertToColor(Color color) =>
    color != null ? GenericColor(color.value) : null;

List<Offset> convertFromStroke(List<GenericOffset> genericStroke) =>
    genericStroke
        .map((genericOffset) => convertFromOffset(genericOffset))
        .toList();
List<GenericOffset> convertToStroke(List<Offset> stroke) =>
    stroke.map((offset) => convertToOffset(offset)).toList();

List<List<Offset>> convertFromStrokes(
        List<List<GenericOffset>> genericStrokes) =>
    List.generate(
        genericStrokes.length, (i) => convertFromStroke(genericStrokes[i]));
List<List<GenericOffset>> convertToStrokes(List<List<Offset>> strokes) =>
    List.generate(strokes.length, (i) => convertToStroke(strokes[i]));
