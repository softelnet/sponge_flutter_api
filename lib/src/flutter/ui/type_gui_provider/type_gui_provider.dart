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
import 'package:logging/logging.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_providers_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/util/utils.dart';

typedef UnitTypeGuiProviderSupplier = UnitTypeGuiProvider Function(
    DataType type);

abstract class TypeGuiProviderRegistry {
  final Map<DataTypeKind, List<UnitTypeGuiProviderSupplier>> providerSuppliers =
      {};

  void register(DataTypeKind typeKind, UnitTypeGuiProviderSupplier supplier) {
    providerSuppliers.putIfAbsent(
        typeKind, () => <UnitTypeGuiProviderSupplier>[]);
    providerSuppliers[typeKind].insert(0, supplier);
  }

  void registerAll(Map<DataTypeKind, UnitTypeGuiProviderSupplier> suppliers) =>
      suppliers.forEach(register);

  void unregister(DataTypeKind typeKind) => providerSuppliers.remove(typeKind);

  /// Returns a new instance of the unit type provider. Therefore it may be used as a statefull entity.
  TypeGuiProvider getProvider(DataType type) {
    var suppliers = Validate.notNull(
        providerSuppliers[type.kind], 'Unsupported type ${type.kind}');

    return TypeGuiProvider(type, this, suppliers);
  }
}

class TypeGuiProvider<T extends DataType> {
  TypeGuiProvider(this.type, this.typeProviderRegistry,
      List<UnitTypeGuiProviderSupplier> suppliers)
      : suppliers = suppliers ?? [];

  static final Logger _logger = Logger('DelegatingUnitTypeGuiProvider');

  final DataType type;
  final TypeGuiProviderRegistry typeProviderRegistry;
  final List<UnitTypeGuiProviderSupplier> suppliers;

  V _traverse<V>(V Function(UnitTypeGuiProvider<T> provider) onProvider) =>
      suppliers
          .map<V>((supplier) => onProvider(
              supplier(type)..typeProviderRegistry = typeProviderRegistry))
          .firstWhere((value) => value != null, orElse: () => null);

  Widget createEditor(TypeEditorContext editorContext) {
    setupContext(editorContext);

    try {
      return _wrapIfLoading(
              (_) =>
                  _traverse((provider) => provider.createEditor(editorContext)),
              editorContext) ??
          TypeGuiProviderUtils.createUnsupportedTypeEditor(type,
              labelText: editorContext.safeTypeLabel,
              hintText: editorContext.hintText);
    } catch (e) {
      return TypeGuiProviderUtils.createUnsupportedTypeEditor(type,
          labelText: editorContext.safeTypeLabel,
          hintText: editorContext.hintText,
          message: e.toString());
    }
  }

  Widget createCompactViewer(TypeViewerContext viewerContext) {
    setupContext(viewerContext);

    try {
      // TODO createCompactViewer with valueLabel. Is this OK?
      if (viewerContext.valueLabel != null) {
        return _wrapIfLoading(
            (_) => TypeGuiProviderUtils.createTextBasedCompactViewer(
                viewerContext.clone()..value = viewerContext.valueLabel),
            viewerContext);
      }

      return _wrapIfLoading(
              (_) => _traverse(
                  (provider) => provider.createCompactViewer(viewerContext)),
              viewerContext) ??
          TypeGuiProviderUtils.createUnsupportedTypeViewer(this,
              labelText: viewerContext.safeTypeLabel);
    } catch (e) {
      return TypeGuiProviderUtils.createUnsupportedTypeViewer(this,
          labelText: viewerContext.safeTypeLabel, message: e.toString());
    }
  }

  Widget createViewer(TypeViewerContext viewerContext) {
    setupContext(viewerContext);

    try {
      return _wrapIfLoading(
              (_) =>
                  _traverse((provider) => provider.createViewer(viewerContext)),
              viewerContext) ??
          TypeGuiProviderUtils.createUnsupportedTypeViewer(this,
              labelText: viewerContext.safeTypeLabel);
    } catch (e) {
      return TypeGuiProviderUtils.createUnsupportedTypeViewer(this,
          labelText: viewerContext.safeTypeLabel, message: e.toString());
    }
  }

  Widget createExtendedViewer(TypeViewerContext viewerContext) {
    setupContext(viewerContext);

    try {
      return _traverse(
          (provider) => provider.createExtendedViewer(viewerContext));
    } catch (e) {
      _logger.severe('Extended viewer error', e);
      rethrow;
    }
  }

  void setupContext(UiContext uiContext) => UiContext.setupContext(uiContext);

  Widget _wrapIfLoading(WidgetBuilder builder, UiContext uiContext) {
    bool isLoading = uiContext.isThisValueLoading;

    if (DataTypeUtils.isValueNotSet(uiContext.value) && isLoading) {
      return TypeGuiProviderUtils.createWaitingViewer(uiContext);
    }

    var widget = builder(uiContext.context);

    return widget != null && isLoading
        ? AbsorbPointer(
            child: widget,
            absorbing: true,
          )
        : widget;

    // TODO ModalProgressHUD would be the best widget here but causes rendering errors, e.g. for pageable lists.

    // return widget != null
    //     ? ModalProgressHUD(
    //         child: widget,
    //         inAsyncCall: TypeGuiProviderUtils.isWaitingForValue(uiContext),
    //       )
    //     : null;
  }

  Future<void> navigateToExtendedViewer(TypeViewerContext viewerContext) async {
    var viewer = createExtendedViewer(viewerContext);
    if (viewer != null) {
      await Navigator.push(
        viewerContext.context,
        createPageRoute(
          viewerContext.context,
          builder: (context) => SwipeDetector(
            child: viewer,
            onSwipe: (context) => Navigator.pop(context),
          ),
        ),
      );
    }
  }
}

abstract class UnitTypeGuiProvider<T extends DataType> {
  UnitTypeGuiProvider(this.type);

  final T type;
  TypeGuiProviderRegistry typeProviderRegistry;

  Widget createEditor(TypeEditorContext editorContext);

  Widget createCompactViewer(TypeViewerContext viewerContext);

  Widget createViewer(TypeViewerContext viewerContext);

  /// An extended viewer is optional so this method may return `null`.
  Widget createExtendedViewer(TypeViewerContext viewerContext);
}
