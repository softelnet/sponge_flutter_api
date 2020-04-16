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
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/model_gui_utils.dart';

class TextEditWidget extends StatefulWidget {
  TextEditWidget({
    Key key,
    @required this.editorContext,
    @required this.inputType,
    this.validator,
    this.maxLines,
    @required this.onGetValueFromString,
  }) : super(key: key);

  final TypeEditorContext editorContext;
  final TextInputType inputType;
  final TypeEditorValidatorCallback validator;
  final int maxLines;
  final dynamic Function(String) onGetValueFromString;

  @override
  _TextEditWidgetState createState() => _TextEditWidgetState();
}

class _TextEditWidgetState extends State<TextEditWidget> {
  TextEditingController _controller;

  String get _sourceValue => widget.editorContext.value?.toString() ?? '';

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: _sourceValue)
      ..addListener(() {
        widget.editorContext
            .onUpdate(widget.onGetValueFromString(_controller.text));
      });
  }

  @override
  void dispose() {
    super.dispose();

    _controller?.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controller.value =
        TextEditingController.fromValue(TextEditingValue(text: _sourceValue))
            .value;
  }

  @override
  Widget build(BuildContext context) {
    return _createTextEditWidget(
      widget.editorContext,
      inputType: widget.inputType,
    );
  }

  Widget _createTextEditWidget<T extends DataType>(
    TypeEditorContext editorContext, {
    @required TextInputType inputType,
    TypeEditorValidatorCallback validator,
    int maxLines,
  }) {
    var decoration = InputDecoration(
        border: InputBorder.none,
        labelText: editorContext.getDecorationLabel(),
        hintText: editorContext.hintText,
        suffixIcon: editorContext.enabled && !editorContext.readOnly
            ? InkResponse(
                key: Key('text-clear'),
                child: Icon(
                  MdiIcons.close,
                  //Icons.cancel,
                  color: Colors.grey,
                  size: getArgLabelTextStyle(editorContext.context).fontSize *
                      1.5,
                ),
                onTap: () => WidgetsBinding.instance
                    .addPostFrameCallback((_) => _controller.clear()))
            : null);
    bool obscure = Features.getOptional(
        editorContext.features, Features.STRING_OBSCURE, () => false);

    return TextFormField(
      key: createDataTypeKey(editorContext.qualifiedType),
      controller: _controller,
      keyboardType: inputType,
      decoration: decoration,
      // Both callbacks onFieldSubmitted and onSaved are necessary.
      onFieldSubmitted: (String value) {
        editorContext.onSave(widget.onGetValueFromString(value));
      },
      onSaved: (String value) {
        editorContext.onSave(widget.onGetValueFromString(value));
      },
      validator: (value) {
        if (!editorContext.qualifiedType.type.nullable && value.isEmpty) {
          return '${editorContext.qualifiedType.type.label ?? "Value"} is required';
        }

        return validator != null
            ? validator(widget.onGetValueFromString(value))
            : null;
      },
      maxLines: obscure ? 1 : maxLines,
      enabled: editorContext.enabled && !editorContext.readOnly,
      obscureText: obscure,
    );
  }
}

