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

import 'package:flutter/material.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/util/model_utils.dart';
import 'package:sponge_flutter_api/src/common/util/type_gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type_support/provided_value_set_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/error_widgets.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type_support/sub_actions.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type_support/text_view_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/widgets.dart';

class RecordTypeWidget extends StatefulWidget {
  RecordTypeWidget({
    Key key,
    @required this.uiContext,
    this.showBorder = false,
  }) : super(key: key) {
    Validate.isTrue(
        uiContext.qualifiedType.type is RecordType, 'Record type expected');
  }

  final UiContext uiContext;
  final bool showBorder;

  @override
  _RecordTypeWidgetState createState() => _RecordTypeWidgetState();
}

class _RecordTypeWidgetState extends State<RecordTypeWidget> {
  Map<String, TypeGuiProvider> _typeGuiProviders;
  bool _isExpanded;

  bool get isRecordReadOnly => widget.uiContext.readOnly;

  bool get isRecordEnabled => widget.uiContext.enabled;

  bool _hasRootRecordSingleLeadingField() {
    var thisLeadingFieldPath = ModelUtils.getRootRecordSingleLeadingField(
            widget.uiContext.qualifiedType, widget.uiContext.value as Map)
        ?.qType
        ?.path;

    return widget.uiContext.rootRecordSingleLeadingField != null &&
        widget.uiContext.rootRecordSingleLeadingField == thisLeadingFieldPath;
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (_hasRootRecordSingleLeadingField()) {
        return _buildFieldsWidgets(context)[0];
      } else {
        return _build(context);
      }
    } catch (e) {
      return Center(
        child: NotificationPanelWidget(
          notification: e,
          type: NotificationPanelType.error,
        ),
      );
    }
  }

  Widget _build(BuildContext context) {
    if (_isExpanded == null) {
      _isExpanded = !widget.uiContext.qualifiedType.type.nullable &&
              widget.uiContext.value != null ||
          widget.uiContext.value != null;
    } else if (_isExpanded && widget.uiContext.value == null) {
      _isExpanded = false;
    }

    var label = widget.uiContext.getDecorationLabel();

    var margin = EdgeInsets.only(bottom: 5);

    // Return widget for null record in the read only mode.
    if (isRecordReadOnly &&
        DataTypeUtils.isValueNotSet(widget.uiContext.value)) {
      return TextViewWidget(
        label: label,
        text: null,
        compact: true,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (widget.uiContext.qualifiedType.type.nullable ||
                DataTypeUtils.isValueNotSet(widget.uiContext.value))
              IconButton(
                key: Key('record-expand'),
                icon: Icon(_isExpanded
                    ? Icons.check_box
                    : Icons.check_box_outline_blank),
                tooltip: 'Set nullable value',
                onPressed: isRecordEnabled && !isRecordReadOnly
                    ? () {
                        setState(() {
                          _toggleExpand();
                        });
                      }
                    : null,
              ),
            if (label != null)
              Text(
                label,
                style: getArgLabelTextStyle(context),
              ),
          ],
        ),
        if (_isExpanded)
          Container(
            height: 5,
          ),
        if (_isExpanded) ..._buildSubActionsWidget(context),
        if (_isExpanded)
          OptionalExpanded(
            child: widget.uiContext.qualifiedType.isRoot
                ? Container(
                    margin: margin,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildFieldsWidgets(context),
                    ),
                  )
                : Card(
                    margin: margin,
                    elevation: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildFieldsWidgets(context),
                    ),
                    color: Theme.of(widget.uiContext.context)
                        .scaffoldBackgroundColor,
                    shape: widget.showBorder ? ContinuousRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: getBorderColor(widget.uiContext.context),
                      ),
                    ) : null,
                  ),
          ),
      ],
    );
  }

  void _toggleExpand() {
    _isExpanded = !_isExpanded;

    if (_isExpanded) {
      if (widget.uiContext.value == null) {
        var newValue = <String, dynamic>{};
        var defaultValue = DataTypeUtils.unwrapAnnotatedValue(
            widget.uiContext.qualifiedType.type.defaultValue);

        if (defaultValue != null) {
          Validate.isTrue(defaultValue is Map<String, dynamic>,
              'A default value for a record should be a map');
          newValue = defaultValue;
        }

        widget.uiContext.value = newValue;
      }
    } else {
      widget.uiContext.value = null;
    }

    _onSave(widget.uiContext.qualifiedType, widget.uiContext.value);
  }

  List<Widget> _buildSubActionsWidget(BuildContext context) {
    var widgets = <Widget>[];

    // TODO Presenter.
    var service = ApplicationProvider.of(context).service;

    // Show context actions only for normal records (i.e. not for a logical record
    // that represents the action args).
    if (!widget.uiContext.qualifiedType.isRoot) {
      var subActionsWidget = SubActionsWidget.forRecord(
        widget.uiContext,
        service.spongeService,
        tooltip: 'Context actions',
      );

      if (subActionsWidget != null) {
        widgets.add(Align(
          child: Container(
            child: subActionsWidget,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).dividerColor,
            ),
            margin: EdgeInsets.only(bottom: 5, right: 5),
          ),
          alignment: Alignment.centerRight,
        ));
      }
    }

    return widgets;
  }

  List<Widget> _buildFieldsWidgets(BuildContext context) {
    var recordType = widget.uiContext.qualifiedType.type as RecordType;

    // TODO Presenter.
    var service = ApplicationProvider.of(context).service;
    _typeGuiProviders ??= {
      for (var field in recordType.fields)
        field.name: service.getTypeGuiProvider(field)
    };

    var widgets = <Widget>[];

    var groups = _createFieldGroups(recordType);
    groups.asMap().forEach((i, group) {
      widgets.add(_buildFieldGroupWidget(context, group));

      if (i < groups.length - 1) {
        widgets.add(Divider(height: 10));
      }
    });

    return widgets;
  }

  List<List<DataType>> _createFieldGroups(RecordType recordType) {
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

  Widget _buildFieldGroupWidget(
      BuildContext context, List<DataType> fieldGroup) {
    Widget groupWidget;

    List<Widget> rawFieldWidgets = fieldGroup
        .map((fieldType) => _buildFieldWidget(
              context,
              widget.uiContext.qualifiedType,
              widget.uiContext.qualifiedType.createChild(fieldType),
              widget.uiContext.value as Map,
            ))
        .toList();

    if (rawFieldWidgets.length > 1) {
      groupWidget = Wrap(
        spacing: 10,
        runSpacing: 10,
        children: rawFieldWidgets,
      );
    } else if (rawFieldWidgets.length == 1) {
      groupWidget = rawFieldWidgets.first;
    }

    groupWidget = Padding(
      padding: widget.uiContext.rootRecordSingleLeadingField != null &&
              widget.uiContext.qualifiedType.isRoot
          ? const EdgeInsets.all(0)
          : const EdgeInsets.only(left: 10, right: 10, top: 0, bottom: 0),
      child: Align(
        child: groupWidget,
        alignment: Alignment.centerLeft,
      ),
    );

    return
        // Expanded only if any in a group field shoud have a scroll.
        fieldGroup.any(
                (fieldType) => DataTypeGuiUtils.hasListTypeScroll(fieldType))
            ? OptionalExpanded(child: groupWidget)
            : groupWidget;
  }

  void _onSave(QualifiedDataType qType, dynamic value) {
    widget.uiContext.callbacks.onSave(qType, value);
  }

  void _onUpdate(QualifiedDataType qType, dynamic value) {
    widget.uiContext.callbacks.onUpdate(qType, value);
  }

  TypeEditorContext _createEditorContext(
      QualifiedDataType qFieldType, Map record) {
    var qRecordType = widget.uiContext.qualifiedType;

    Validate.notNull(
        record, 'The record ${qRecordType.type.name} must not be null');
    var fieldValue = record[qFieldType.type.name];
    var onSave = (value) => setState(() {
          _onSave(qFieldType, value);
        });
    var onUpdate = (value) => setState(() {
          _onUpdate(qFieldType, value);
        });

    var shouldFieldBeEnabled =
        widget.uiContext.callbacks.shouldBeEnabled(qFieldType);

    return TypeEditorContext(
      widget.uiContext.name,
      context,
      widget.uiContext.callbacks,
      qFieldType,
      fieldValue,
      hintText: qFieldType.type.description,
      onSave: onSave,
      onUpdate: onUpdate,
      readOnly: isRecordReadOnly || !shouldFieldBeEnabled || !isRecordEnabled,
      enabled: isRecordEnabled && shouldFieldBeEnabled,
      loading: widget.uiContext.loading,
      rootRecordSingleLeadingField:
          widget.uiContext.rootRecordSingleLeadingField,
    );
  }

  Widget _buildFieldWidget(BuildContext context, QualifiedDataType recordType,
      QualifiedDataType qFieldType, Map record) {
    try {
      var editorContext = _createEditorContext(qFieldType, record);

      if (qFieldType.type.provided?.hasValueSet ?? false) {
        return AbsorbPointer(
          child: ProvidedValueSetEditorWidget(
            editorContext.getDecorationLabel(),
            qFieldType,
            qFieldType.type.provided.valueSet,
            editorContext.value,
            widget.uiContext.callbacks.onGetProvidedArg,
            editorContext.onSave,
          ),
          absorbing: qFieldType.type.provided.readOnly || !isRecordEnabled,
        );
      }

      var isFieldReadOnly = qFieldType.type.provided?.readOnly ?? false;

      // Switch to a viewer for a record field if necessary.
      if (isRecordReadOnly || isFieldReadOnly || !isRecordEnabled) {
        return Padding(
          padding: EdgeInsets.only(left: 0, right: 0, top: 5, bottom: 5),
          child: _typeGuiProviders[qFieldType.type.name]
              .createViewer(editorContext.cloneAsViewer()),
        );
      }

      return _typeGuiProviders[qFieldType.type.name]
          .createEditor(editorContext);
    } catch (e) {
      return NotificationPanelWidget(
        notification: e,
        type: NotificationPanelType.error,
      );
    }
  }
}
