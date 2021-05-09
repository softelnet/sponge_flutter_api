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

import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/model/events.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';
import 'package:sponge_flutter_api/src/common/util/model_utils.dart';
import 'package:sponge_flutter_api/src/common/util/type_gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';

class RecordTypeViewModel extends BaseViewModel {
  RecordTypeViewModel(this.uiContext);

  final UiContext uiContext;
}

abstract class RecordTypeView extends BaseView {}

class RecordTypePresenter extends BasePresenter<RecordTypeViewModel, RecordTypeView> {
  RecordTypePresenter(RecordTypeViewModel model, RecordTypeView view)
      : super(model.uiContext.service, model, view);

  Map<String, TypeGuiProvider> _typeGuiProviders;
  bool _isExpanded;

  @override
  FlutterApplicationService get service =>
      FlutterApplicationService.of(super.service);

  bool isExpanded() {
    if (_isExpanded == null) {
      _isExpanded =
          !uiContext.qualifiedType.type.nullable && uiContext.value != null ||
              uiContext.value != null;
    } else if (_isExpanded && uiContext.value == null) {
      _isExpanded = false;
    }

    return _isExpanded;
  }

  RecordType get recordType => uiContext.qualifiedType.type as RecordType;

  Map<String, TypeGuiProvider> get typeGuiProviders {
    _typeGuiProviders ??= {
      for (var field in recordType.fields)
        field.name: service.getTypeGuiProvider(field)
    };

    return _typeGuiProviders;
  }

  UiContext get uiContext => viewModel.uiContext;

  bool get isRecordReadOnly => uiContext.readOnly;

  bool get isRecordEnabled => uiContext.enabled;

  bool get isValueNotSet => DataTypeUtils.isValueNotSet(uiContext.value);

  bool get shouldShowNullValue => isRecordReadOnly && isValueNotSet;

  bool get isRoot => uiContext.qualifiedType.isRoot;

  QualifiedDataType get qualifiedRecordType => uiContext.qualifiedType;

  Map get record => uiContext.value as Map;

  bool get isThisRootRecordSingleLeadingField =>
      uiContext.rootRecordSingleLeadingField != null && isRoot;

  /// Show context actions only for normal records (i.e. not for a logical record
  /// that represents the action args).
  bool get shouldShowContextActions => !isRoot;

  bool get shouldShowExpandCheckbox =>
      uiContext.qualifiedType.type.nullable ||
      DataTypeUtils.isValueNotSet(uiContext.value);

  bool get shouldEnableExpandCheckbox => isRecordEnabled && !isRecordReadOnly;

  dynamic getFieldValue(QualifiedDataType qFieldType) {
    Validate.notNull(
        record, 'The record ${qualifiedRecordType.type.name} must not be null');
    return record[qFieldType.type.name];
  }

  bool shouldFieldBeEnabled(QualifiedDataType qFieldType) =>
      uiContext.callbacks.shouldBeEnabled(qFieldType);

  bool hasRootRecordSingleLeadingField() {
    var thisLeadingFieldPath = ModelUtils.getRootRecordSingleLeadingField(
            uiContext.qualifiedType, uiContext.value as Map)
        ?.qType
        ?.path;

    return uiContext.rootRecordSingleLeadingField != null &&
        uiContext.rootRecordSingleLeadingField == thisLeadingFieldPath;
  }

  String get label => uiContext.getDecorationLabel();

  void toggleExpand() {
    _isExpanded = !_isExpanded;

    if (_isExpanded) {
      if (uiContext.value == null) {
        var newValue = <String, dynamic>{};
        var defaultValue = DataTypeUtils.unwrapAnnotatedValue(
            uiContext.qualifiedType.type.defaultValue);

        if (defaultValue != null) {
          Validate.isTrue(defaultValue is Map<String, dynamic>,
              'A default value for a record should be a map');
          newValue = defaultValue;
        }

        uiContext.value = newValue;
      }
    } else {
      uiContext.value = null;
    }

    onSave(SaveValueEvent(uiContext.qualifiedType, uiContext.value));
  }

  List<List<DataType>> createFieldGroups() {
    var groups = <List<DataType>>[];
    String lastGroupName;
    int lastGroupIndex = -1;

    // TODO Util method - merge with annotated features.
    recordType.fields
        .where((fieldType) => fieldType.features[Features.VISIBLE] ?? true)
        .toList()
        .asMap()
        .forEach((i, fieldType) {
      String fieldGroup = fieldType.features[Features.GROUP];
      if (lastGroupName != null && lastGroupName == fieldGroup) {
        groups[lastGroupIndex].add(fieldType);
      } else {
        groups.add([fieldType]);
        lastGroupIndex++;
      }

      lastGroupName = fieldGroup;
    });

    return groups;
  }

  bool hasAnyFieldInGroupScroll(List<DataType> fieldGroup) => fieldGroup
      .any((fieldType) => DataTypeGuiUtils.hasListTypeScroll(fieldType));

  void onSave(SaveValueEvent event) {
    uiContext.callbacks.onSave(event);
  }

  void onUpdate(UpdateValueEvent event) {
    uiContext.callbacks.onUpdate(event);
  }
}
