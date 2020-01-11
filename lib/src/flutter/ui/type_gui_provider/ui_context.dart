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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/flutter/state_container.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';

abstract class UiContextCallbacks {
  void onSave(QualifiedDataType qType, dynamic value);
  void onUpdate(QualifiedDataType qType, dynamic value);
  void onActivate(QualifiedDataType qType, dynamic value);
  ProvidedValue onGetProvidedArg(QualifiedDataType qType);
  Future<void> onRefresh();
  Future<void> onRefreshArgs();
  Future<bool> onSaveForm();
  Future<void> onBeforeSubActionCall();
  Future<void> onAfterSubActionCall(ActionCallState state);
  bool shouldBeEnabled(QualifiedDataType qType);
  PageableList getPageableList(QualifiedDataType qType);
  Future<void> fetchPageableListPage(QualifiedDataType qType);
  String getKey(String code);
}

class NoOpUiContextCallbacks implements UiContextCallbacks {
  @override
  void onSave(QualifiedDataType qType, dynamic value) {}

  @override
  void onUpdate(QualifiedDataType qType, dynamic value) {}

  @override
  void onActivate(QualifiedDataType qType, value) {}

  @override
  ProvidedValue onGetProvidedArg(QualifiedDataType qType) => null;

  @override
  Future<void> onRefresh() async {}

  @override
  bool shouldBeEnabled(QualifiedDataType qType) => true;

  @override
  Future<void> onRefreshArgs() async {}

  @override
  Future<bool> onSaveForm() async => true;

  @override
  Future<void> onAfterSubActionCall(ActionCallState state) async {}

  @override
  Future<void> onBeforeSubActionCall() async {}

  @override
  PageableList getPageableList(QualifiedDataType qType) => null;

  @override
  Future<void> fetchPageableListPage(QualifiedDataType qType) => null;

  @override
  String getKey(String code) => null;
}

typedef String TypeEditorValidatorCallback(String value);

abstract class UiContext {
  UiContext(
    this.name,
    this.context,
    this.callbacks,
    this.qualifiedType,
    String typeLabel,
    String typeDescription,
    this.value, {
    @required this.valueLabel,
    @required this.valueDescription,
    @required Map<String, Object> features,
    @required bool markNullable,
    @required bool showLabel,
    @required List<String> providing,
  })  : this.features = features != null ? Map.from(features) : {},
        this.markNullable = markNullable ?? true {
    this.typeLabel = typeLabel ?? qualifiedType.type.label;
    this.typeDescription = typeDescription ?? qualifiedType.type.description;
    this.showLabel = showLabel ?? true;
    this.providing = providing ?? [];
  }

  final String name;
  final BuildContext context;
  final UiContextCallbacks callbacks;
  QualifiedDataType qualifiedType;
  String typeLabel;
  String typeDescription;
  dynamic value;

  String valueLabel;
  String valueDescription;
  Map<String, Object> features;
  bool markNullable;
  bool showLabel;
  List<String> providing;

  bool get enabled;

  TypeGuiProvider get typeGuiProvider =>
      StateContainer.of(context).service.typeGuiProvider;

  String get safeTypeLabel => typeLabel ?? qualifiedType.type.name;

  String getDecorationLabel({String customLabel}) {
    // TODO Apply features.
    var label = customLabel ?? (showLabel ? typeLabel : null);
    if (label == null) {
      return null;
    }

    return markNullable
        ? (label + (qualifiedType.type.nullable ? '' : ' *'))
        : label;
  }
}

class TypeEditorContext extends UiContext {
  TypeEditorContext(
    String name,
    BuildContext context,
    UiContextCallbacks callbacks,
    QualifiedDataType qualifiedType,
    dynamic value, {
    String typeLabel,
    String typeDescription,
    String valueLabel,
    String valueDescription,
    Map<String, Object> features,
    bool markNullable,
    this.hintText,
    this.onSave,
    this.onUpdate,
    this.validator,
    this.readOnly = false,
    @required bool enabled,
    bool showLabel,
    @required List<String> providing,
  }) : super(
          name,
          context,
          callbacks,
          qualifiedType,
          typeLabel,
          typeDescription,
          value,
          valueLabel: valueLabel,
          valueDescription: valueDescription,
          features: features,
          markNullable: markNullable,
          showLabel: showLabel,
          providing: providing,
        ) {
    this.enabled = enabled ?? true;
  }

  String hintText;
  ValueChanged onSave;
  ValueChanged onUpdate;
  TypeEditorValidatorCallback validator;
  bool readOnly;
  bool enabled;

  TypeEditorContext copy() => TypeEditorContext(
        name,
        context,
        callbacks,
        qualifiedType,
        value,
        typeLabel: typeLabel,
        typeDescription: typeDescription,
        valueLabel: valueLabel,
        valueDescription: valueDescription,
        features: Map.from(features),
        markNullable: markNullable,
        hintText: hintText,
        onSave: onSave,
        onUpdate: onUpdate,
        validator: validator,
        readOnly: readOnly,
        enabled: enabled,
        showLabel: showLabel,
        providing: providing,
      );

  TypeViewerContext copyAsViewer() => TypeViewerContext(
        name,
        context,
        callbacks,
        qualifiedType,
        value,
        typeLabel: typeLabel,
        typeDescription: typeDescription,
        valueLabel: valueLabel,
        valueDescription: valueDescription,
        features: Map.from(features),
        markNullable: markNullable,
        showLabel: showLabel,
        providing: providing,
      );
}

class TypeViewerContext extends UiContext {
  TypeViewerContext(
    String name,
    BuildContext context,
    UiContextCallbacks callbacks,
    QualifiedDataType qualifiedType,
    dynamic value, {
    String typeLabel,
    String typeDescription,
    String valueLabel,
    String valueDescription,
    Map<String, Object> features,
    bool markNullable,
    bool showLabel,
    @required List<String> providing,
  }) : super(
          name,
          context,
          callbacks,
          qualifiedType,
          typeLabel,
          typeDescription,
          value,
          valueLabel: valueLabel,
          valueDescription: valueDescription,
          features: features,
          markNullable: markNullable,
          showLabel: showLabel,
          providing: providing,
        );

  bool get enabled => false;

  TypeViewerContext copy() => TypeViewerContext(
        name,
        context,
        callbacks,
        qualifiedType,
        value,
        typeLabel: typeLabel,
        typeDescription: typeDescription,
        valueLabel: valueLabel,
        valueDescription: valueDescription,
        features: Map.from(features),
        markNullable: markNullable,
        showLabel: showLabel,
        providing: providing,
      );

  TypeEditorContext copyAsEditor() => TypeEditorContext(
        name,
        context,
        callbacks,
        qualifiedType,
        value,
        typeLabel: typeLabel,
        typeDescription: typeDescription,
        valueLabel: valueLabel,
        valueDescription: valueDescription,
        features: Map.from(features),
        markNullable: markNullable,
        showLabel: showLabel,
        enabled: true,
        providing: providing,
      );
}
