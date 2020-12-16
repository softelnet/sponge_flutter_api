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
import 'package:sponge_flutter_api/src/common/util/common_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/model_gui_utils.dart';

// TODO Handle readOnly providedValueSet.
// TODO Handle value set in GuiProviders - typed.
class ProvidedValueSetEditorWidget extends StatefulWidget {
  ProvidedValueSetEditorWidget(
    this.label,
    this.qType,
    this.valueSetMeta,
    this.value,
    this.onGetProvidedArg,
    this.onSaved,
  );
  final String label;
  final QualifiedDataType qType;
  final ValueSetMeta valueSetMeta;
  final dynamic value;
  final GetProvidedArgCallback onGetProvidedArg;
  final ValueChanged onSaved;

  @override
  _ProvidedValueSetEditorWidgetState createState() =>
      _ProvidedValueSetEditorWidgetState();
}

class _ProvidedValueSetEditorWidgetState
    extends State<ProvidedValueSetEditorWidget> {
  TextEditingController _controller;

  /// Creates a new controller initially and every time an argument value has changed.
  TextEditingController getOrCreateController() {
    if (_controller == null || widget.value != _controller.text) {
      // TODO Dispose controller when creating a new one.
      _controller = TextEditingController(text: widget.value?.toString() ?? '')
        ..addListener(() {
          widget.onSaved(CommonUtils.normalizeString(_controller.text));
        });
    }

    return _controller;
  }

  @override
  void dispose() {
    super.dispose();

    _controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.valueSetMeta.limited) {
      var items = _getLimitedMenuItems();
      var hasItems = items.isNotEmpty;

      var dropdown = DropdownButtonHideUnderline(
        child: DropdownButton(
          key: createDataTypeKey(widget.qType),
          value: hasItems ? widget.value : null,
          items: hasItems ? items : null,
          onChanged: (value) {
            setState(() {});
            widget.onSaved(value);
          },
          disabledHint: Container(),
          isExpanded: true,
        ),
      );

      return widget.label != null
          ? Row(
              children: <Widget>[
                Text(
                  widget.label,
                  style: getArgLabelTextStyle(context),
                ),
                Container(
                  padding: const EdgeInsets.all(16.0),
                ),
                Expanded(
                  child: dropdown,
                ),
              ],
            )
          : dropdown;
    } else {
      // TODO Only String non-limited values are supported.
      Validate.isTrue(widget.qType.type.kind == DataTypeKind.STRING,
          'Non-limited value set is supported only for a String type');

      var items = _getNotLimitedMenuItems();
      return Row(
        children: <Widget>[
          Flexible(
            child: TextField(
              key: createDataTypeKey(widget.qType),
              decoration: widget.label != null
                  ? InputDecoration(
                      border: InputBorder.none, labelText: widget.label)
                  : null,
              controller: getOrCreateController(),
            ),
          ),
          Visibility(
            child: PopupMenuButton(
              key: Key('popup-${createDataTypeKeyValue(widget.qType)}'),
              itemBuilder: (BuildContext context) => items,
              onSelected: (value) {
                _controller.text = value?.toString();
              },
            ),
            visible: !(items?.isEmpty ?? true),
          ),
        ],
      );
    }
  }

  List<AnnotatedValue> _getValueSetValues() {
    ProvidedValue argValue = widget.onGetProvidedArg(widget.qType);
    return argValue?.annotatedValueSet
            ?.where((annotatedValue) => annotatedValue != null)
            ?.toList() ??
        [];
  }

  List<DropdownMenuItem<dynamic>> _getLimitedMenuItems() {
    List<AnnotatedValue> valueSetValues = _getValueSetValues();

    // If the type is nullable and has value set that contains no null values, insert a first element that has a null value.
    if (widget.qType.type.nullable &&
        valueSetValues.every((valueSetValue) => valueSetValue?.value != null)) {
      valueSetValues = []
        ..add(AnnotatedValue(null))
        ..addAll(valueSetValues);
    }

    return valueSetValues
        .map((annotatedValue) => DropdownMenuItem(
              value: annotatedValue.value,
              child: Text(annotatedValue.valueLabel ??
                  annotatedValue.value?.toString() ??
                  ''),
            ))
        .toList();
  }

  List<PopupMenuItem> _getNotLimitedMenuItems() {
    return _getValueSetValues()
        .map((annotatedValue) => PopupMenuItem(
              value: annotatedValue.value,
              child: Text(annotatedValue.valueLabel ??
                  annotatedValue.value?.toString() ??
                  ''),
            ))
        .toList();
  }
}
