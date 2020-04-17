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

import 'package:flutter/foundation.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/model/type/type_value.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/drawing_utils.dart';

TypeConverter createTypeConverter(ApplicationService service) =>
    DefaultTypeConverter()
      ..registerAll([
        FlutterBinaryTypeUnitConverter(),
      ]);

Future<String> _marshallBinaryImageDrawing(
    DrawingBinaryValue binaryValue) async {
  return await DrawingUtils.convertImageToPngBase64(
      binaryValue, binaryValue.expectedWidth, binaryValue.expectedHeight);
}

String _marshallBinaryType(List<int> bytes) => base64.encode(bytes);

Uint8List _unmarshallBinaryType(String base64String) =>
    base64.decode(base64String);

/// A binary type unit converter that changes the internal type to dynamic to allow different internal types
/// for binary data.
class FlutterBinaryTypeUnitConverter
    extends UnitTypeConverter<dynamic, BinaryType> {
  FlutterBinaryTypeUnitConverter() : super(DataTypeKind.BINARY);

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
          return await _marshallBinaryImageDrawing(value as DrawingBinaryValue);
        }
        break;
    }

    return await compute(_marshallBinaryType, value as List<int>);
  }

  @override
  Future<dynamic> unmarshal(
      TypeConverter converter, BinaryType type, dynamic value) async {
    return await compute(_unmarshallBinaryType, value as String);
  }
}
