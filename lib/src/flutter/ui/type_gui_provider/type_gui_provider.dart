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

import 'package:flutter/material.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/ui_context.dart';

typedef UnitTypeGuiProvider UnitTypeGuiProviderSupplier(DataType type);

abstract class TypeGuiProvider {
  Map<DataTypeKind, UnitTypeGuiProviderSupplier> providerSuppliers = Map();

  void register(DataTypeKind typeKind, UnitTypeGuiProviderSupplier supplier) =>
      providerSuppliers[typeKind] = supplier;

  void registerAll(Map<DataTypeKind, UnitTypeGuiProviderSupplier> suppliers) =>
      suppliers.forEach(register);

  UnitTypeGuiProviderSupplier unregister(DataTypeKind typeKind) =>
      providerSuppliers.remove(typeKind);

  /// Returns a new instance of the unit type provider. Therefore it may be used as a statefull entity.
  UnitTypeGuiProvider getProvider(DataType type) {
    var supplier = Validate.notNull(
        providerSuppliers[type.kind], 'Unsupported type ${type.kind}');
    return supplier(type)..typeProviderRegistry = this;
  }
}

abstract class UnitTypeGuiProvider<T extends DataType> {
  UnitTypeGuiProvider(this.type);

  final T type;
  TypeGuiProvider typeProviderRegistry;

  Widget createEditor(TypeEditorContext editorContext);

  Widget createCompactViewer(TypeViewerContext viewerContext);

  Widget createViewer(TypeViewerContext viewerContext);

  /// An extended viewer is optional so this method may return `null`.
  Widget createExtendedViewer(TypeViewerContext viewerContext);

  dynamic getValueFromString(String s);

  void setupContext(UiContext uiContext);
}
