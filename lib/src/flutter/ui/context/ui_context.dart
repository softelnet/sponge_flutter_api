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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context_callbacks.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';

typedef TypeEditorValidatorCallback = String Function(dynamic value);

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
    @required List<String> loading,
    @required bool enabled,
    @required bool readOnly,
    @required this.rootRecordSingleLeadingField,
    bool isRootUiContext,
  })  : features = features != null ? Map.from(features) : {},
        markNullable = markNullable ?? true {
    this.typeLabel = typeLabel ?? qualifiedType.type.label;
    this.typeDescription = typeDescription ?? qualifiedType.type.description;
    this.showLabel = showLabel ?? true;
    this.loading = loading ?? [];
    this.enabled = enabled;
    this.readOnly = readOnly;

    this.isRootUiContext = isRootUiContext ?? false;

    _setup();
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
  List<String> loading;

  bool enabled;
  bool readOnly;
  String rootRecordSingleLeadingField;

  // Should not be cloned.
  bool isRootUiContext;

  bool _isSetUp = false;

  FlutterApplicationService get service => callbacks.service;

  TypeGuiProviderRegistry get typeGuiProviderRegistry =>
      service.typeGuiProviderRegistry;

  String get safeTypeLabel => typeLabel ?? qualifiedType.type.name;

  String getDecorationLabel({String customLabel}) {
    var label = customLabel ?? (showLabel ? typeLabel : null);
    if (label == null) {
      return null;
    }

    return markNullable
        ? (label + (qualifiedType.type.nullable ? '' : ' *'))
        : label;
  }

  void _setup() {
    if (_isSetUp) {
      return;
    }

    _doSetup();

    _isSetUp = true;
  }

  @mustCallSuper
  void _doSetup() {
    var type = qualifiedType.type;

    // Merge features before unwrapping an annotated value.
    features = DataTypeUtils.mergeFeatures(type, value);

    // Applying annotated properties.
    if (type.annotated && value is AnnotatedValue) {
      var annotatedValue = value as AnnotatedValue;
      value = annotatedValue.value;
      valueLabel = annotatedValue.valueLabel;
      valueDescription = annotatedValue.valueDescription;

      if (annotatedValue.typeLabel != null) {
        typeLabel = annotatedValue.typeLabel;
      }

      if (annotatedValue.typeDescription != null) {
        typeDescription = annotatedValue.typeDescription;
      }
    }
  }

  bool get isThisValueLoading =>
      qualifiedType.path != null && loading.contains(qualifiedType.path);

  bool get isAnyValueLoading => loading.isNotEmpty;

  bool get isThisRootRecordSingleLeadingField =>
      rootRecordSingleLeadingField != null &&
      rootRecordSingleLeadingField == qualifiedType.path;
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
    bool readOnly,
    @required bool enabled,
    bool showLabel,
    @required List<String> loading,
    String rootRecordSingleLeadingField,
    bool isRootUiContext,
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
          loading: loading,
          enabled: enabled ?? true,
          readOnly: readOnly ?? false,
          rootRecordSingleLeadingField: rootRecordSingleLeadingField,
          isRootUiContext: isRootUiContext,
        );

  String hintText;
  ValueChanged onSave;
  ValueChanged onUpdate;
  TypeEditorValidatorCallback validator;

  @override
  void _doSetup() {
    super._doSetup();

    enabled = enabled && (features[Features.ENABLED] ?? true);
    readOnly = readOnly || qualifiedType.type.readOnly;
  }

  TypeEditorContext clone() => TypeEditorContext(
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
        loading: loading,
        rootRecordSingleLeadingField: rootRecordSingleLeadingField,
      );

  TypeViewerContext cloneAsViewer() => TypeViewerContext(
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
        loading: loading,
        rootRecordSingleLeadingField: rootRecordSingleLeadingField,
      );

  bool get hasRootRecordSingleLeadingField =>
      rootRecordSingleLeadingField != null;
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
    @required List<String> loading,
    String rootRecordSingleLeadingField,
    bool isRootUiContext,
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
          loading: loading,
          enabled: false,
          readOnly: true,
          rootRecordSingleLeadingField: rootRecordSingleLeadingField,
          isRootUiContext: isRootUiContext,
        );

  TypeViewerContext clone() => TypeViewerContext(
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
        loading: loading,
        rootRecordSingleLeadingField: rootRecordSingleLeadingField,
      );

  TypeEditorContext cloneAsEditor() => TypeEditorContext(
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
        loading: loading,
        rootRecordSingleLeadingField: rootRecordSingleLeadingField,
      );
}
