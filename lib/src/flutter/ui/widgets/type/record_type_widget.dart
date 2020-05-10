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
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/mvp/widgets/type/record_type_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/error_widgets.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type_support/provided_value_set_widget.dart';
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

class _RecordTypeWidgetState extends State<RecordTypeWidget>
    implements RecordTypeView {
  RecordTypePresenter _presenter;

  @override
  Widget build(BuildContext context) {
    var model = RecordTypeViewModel(widget.uiContext);

    _presenter ??= RecordTypePresenter(model, this);

    // The model contains the UiContext so it has to be updated every build.
    _presenter.updateModel(model);

    try {
      if (_presenter.hasRootRecordSingleLeadingField()) {
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
    var label = _presenter.label;
    bool isExpanded = _presenter.isExpanded();

    var margin = const EdgeInsets.only(bottom: 5);

    // Return widget for a null record in the read only mode.
    if (_presenter.shouldShowNullValue) {
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
            if (_presenter.shouldShowExpandCheckbox)
              IconButton(
                key: Key('record-expand'),
                icon: Icon(isExpanded
                    ? Icons.check_box
                    : Icons.check_box_outline_blank),
                tooltip: 'Set nullable value',
                onPressed: _presenter.shouldEnableExpandCheckbox
                    ? () => setState(() => _presenter.toggleExpand())
                    : null,
              ),
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  label,
                  style: getArgLabelTextStyle(context),
                ),
              ),
          ],
        ),
        if (isExpanded) Container(height: 5),
        if (isExpanded) ..._buildSubActionsWidget(context),
        if (isExpanded)
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
                    shape: widget.showBorder
                        ? ContinuousRectangleBorder(
                            side: BorderSide(
                              width: 1,
                              color: getBorderColor(widget.uiContext.context),
                            ),
                          )
                        : null,
                  ),
          ),
      ],
    );
  }

  List<Widget> _buildSubActionsWidget(BuildContext context) {
    var widgets = <Widget>[];

    if (_presenter.shouldShowContextActions) {
      var subActionsWidget = SubActionsWidget.forRecord(
        widget.uiContext,
        _presenter.service.spongeService,
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
            margin: const EdgeInsets.only(bottom: 5, right: 5),
          ),
          alignment: Alignment.centerRight,
        ));
      }
    }

    return widgets;
  }

  List<Widget> _buildFieldsWidgets(BuildContext context) {
    var widgets = <Widget>[];

    var groups = _presenter.createFieldGroups();
    groups.asMap().forEach((i, group) {
      widgets.add(_buildFieldGroupWidget(context, group));

      if (i < groups.length - 1) {
        widgets.add(const Divider(height: 10));
      }
    });

    return widgets;
  }

  Widget _buildFieldGroupWidget(
      BuildContext context, List<DataType> fieldGroup) {
    Widget groupWidget;

    List<Widget> rawFieldWidgets = fieldGroup
        .map((fieldType) => _buildFieldWidget(
            context,
            widget.uiContext.qualifiedType,
            widget.uiContext.qualifiedType.createChild(fieldType)))
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
      padding: _presenter.isThisRootRecordSingleLeadingField
          ? const EdgeInsets.all(0)
          : EdgeInsets.only(
              left: 10,
              right: (widget.showBorder || _presenter.uiContext.isRootUiContext)
                  ? 10
                  : 0),
      child: Align(
        child: groupWidget,
        alignment: Alignment.centerLeft,
      ),
    );

    return
        // Expanded only if any in a group field shoud have a scroll.
        _presenter.hasAnyFieldInGroupScroll(fieldGroup)
            ? OptionalExpanded(child: groupWidget)
            : groupWidget;
  }

  TypeEditorContext _createEditorContext(QualifiedDataType qFieldType) {
    var shouldFieldBeEnabled = _presenter.shouldFieldBeEnabled(qFieldType);

    return TypeEditorContext(
      widget.uiContext.name,
      context,
      widget.uiContext.callbacks,
      qFieldType,
      _presenter.getFieldValue(qFieldType),
      hintText: qFieldType.type.description,
      onSave: (value) => setState(() => _presenter.onSave(qFieldType, value)),
      onUpdate: (value) =>
          setState(() => _presenter.onUpdate(qFieldType, value)),
      readOnly: _presenter.isRecordReadOnly ||
          !shouldFieldBeEnabled ||
          !_presenter.isRecordEnabled,
      enabled: _presenter.isRecordEnabled && shouldFieldBeEnabled,
      loading: widget.uiContext.loading,
      rootRecordSingleLeadingField:
          widget.uiContext.rootRecordSingleLeadingField,
    );
  }

  Widget _buildFieldWidget(BuildContext context, QualifiedDataType recordType,
      QualifiedDataType qFieldType) {
    try {
      var editorContext = _createEditorContext(qFieldType);

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
          absorbing: qFieldType.type.readOnly || !_presenter.isRecordEnabled,
        );
      }

      var isFieldReadOnly = qFieldType.type.readOnly;

      // Switch to a viewer for a record field if necessary.
      if (_presenter.isRecordReadOnly ||
          isFieldReadOnly ||
          !_presenter.isRecordEnabled) {
        return Padding(
          padding: const EdgeInsets.only(left: 0, right: 0, top: 5, bottom: 5),
          child: _presenter.typeGuiProviders[qFieldType.type.name]
              .createViewer(editorContext.cloneAsViewer()),
        );
      }

      return _presenter.typeGuiProviders[qFieldType.type.name]
          .createEditor(editorContext);
    } catch (e) {
      return NotificationPanelWidget(
        notification: e,
        type: NotificationPanelType.error,
      );
    }
  }
}
