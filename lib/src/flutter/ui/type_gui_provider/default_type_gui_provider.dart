// Copyright 2019 The Sponge authors.
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
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/unit_type_gui_providers.dart';

class DefaultTypeGuiProvider extends TypeGuiProvider {
  DefaultTypeGuiProvider() {
    // Register default GUI providers.
    this.registerAll({
      DataTypeKind.ANY: (type) => AnyTypeGuiProvider(type),
      DataTypeKind.BINARY: (type) => BinaryTypeGuiProvider(type),
      DataTypeKind.BOOLEAN: (type) => BooleanTypeGuiProvider(type),
      DataTypeKind.DATE_TIME: (type) => DateTimeTypeGuiProvider(type),
      DataTypeKind.DYNAMIC: (type) => DynamicTypeGuiProvider(type),
      DataTypeKind.INTEGER: (type) => IntegerTypeGuiProvider(type),
      DataTypeKind.LIST: (type) => ListTypeGuiProvider(type),
      DataTypeKind.MAP: (type) => MapTypeGuiProvider(type),
      DataTypeKind.NUMBER: (type) => NumberTypeGuiProvider(type),
      DataTypeKind.OBJECT: (type) => ObjectTypeGuiProvider(type),
      DataTypeKind.RECORD: (type) => RecordTypeGuiProvider(type),
      DataTypeKind.STREAM: (type) => StreamTypeGuiProvider(type),
      DataTypeKind.STRING: (type) => StringTypeGuiProvider(type),
      DataTypeKind.TYPE: (type) => TypeTypeGuiProvider(type),
      DataTypeKind.VOID: (type) => VoidTypeGuiProvider(type),
    });
  }
}
