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
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/drawing.dart';
import 'package:sponge_flutter_api/src/type/generic_type.dart';
import 'package:sponge_flutter_api/src/type/type_value.dart';

TypeConverter createTypeConverter(ApplicationService service) =>
    DefaultTypeConverter()
      ..registerAll([
        MobileBinaryTypeUnitConverter(),
        ObjectTypeUnitConverter()
          ..addMarshaler(
              SpongeClientConstants.REMOTE_EVENT_OBJECT_TYPE_CLASS_NAME,
              _createRemoteEventMarshaller(service)),
      ]);

ObjectTypeUnitConverterMapper _createRemoteEventMarshaller(
        ApplicationService service) =>
    (converter, value) async {
      RemoteEvent event = value as RemoteEvent;

      return await event.convertToJson(
          Validate.notNull(
              await service.spongeService.client.getEventType(event.name),
              'Event type ${event.name} not found'),
          converter);
    };

Future<String> marshallBinaryImageDrawing(
    DrawingBinaryValue binaryValue) async {
  return await convertImageToPngBase64(
      binaryValue, binaryValue.expectedWidth, binaryValue.expectedHeight);
}

String marshallBinaryType(List<int> bytes) => base64.encode(bytes);

Uint8List unmarshallBinaryType(String base64String) =>
    base64.decode(base64String);

/// A binary type unit converter that changes the internal type to dynamic to allow different internal types
/// for binary data.
class MobileBinaryTypeUnitConverter
    extends UnitTypeConverter<dynamic, BinaryType> {
  MobileBinaryTypeUnitConverter() : super(DataTypeKind.BINARY);

  @override
  Future<dynamic> marshal(
      TypeConverter converter, BinaryType type, dynamic value) async {
    String mimeType = DataTypeUtils.getFeatureOrProperty(
        type, value, BinaryType.FEATURE_MIME_TYPE, () => type.mimeType);
    switch (mimeType) {
      case 'image/png':
        if (Features.getCharacteristic(type.features) ==
            Features.TYPE_CHARACTERISTIC_DRAWING) {
          // An outgoing drawing (an action argument) is represented internally as a custom type DrawingBinaryValue.
          return await marshallBinaryImageDrawing(value as DrawingBinaryValue);
        }
        break;
    }

    return await compute(marshallBinaryType, value as List<int>);
  }

  @override
  Future<dynamic> unmarshal(
      TypeConverter converter, BinaryType type, dynamic value) async {
    return await compute(unmarshallBinaryType, value as String);
  }
}

FeatureConverter createFeatureConverter(ApplicationService service) =>
    DefaultFeatureConverter();

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
