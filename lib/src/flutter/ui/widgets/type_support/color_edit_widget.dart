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
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/model_gui_utils.dart';

class ColorEditWidget extends StatefulWidget {
  ColorEditWidget({
    Key key,
    @required this.name,
    @required this.initialColor,
    @required this.onColorChanged,
    @required this.defaultColor,
    this.enabled = true,
  }) : super(key: key);

  final String name;
  final Color initialColor;
  final Color defaultColor;
  final ValueChanged<Color> onColorChanged;
  final bool enabled;

  @override
  _ColorEditWidgetState createState() => _ColorEditWidgetState();
}

class _ColorEditWidgetState extends State<ColorEditWidget> {
  Color _currentPickerColor;

  @override
  Widget build(BuildContext context) {
    var suggestedColor = widget.initialColor ?? widget.defaultColor;
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: suggestedColor,
      ),
      onPressed: widget.enabled
          ? () => showColorPicker(context, suggestedColor)
          : null,
      child: Text(
        '${widget.name ?? 'Color'}${widget.initialColor != null ? " (" + color2string(widget.initialColor) + ")" : ""}',
        style: TextStyle(color: getContrastColor(suggestedColor)),
      ),
    );
  }

  Future<void> showColorPicker(
      BuildContext context, Color suggestedColor) async {
    Color choosenColor = await showDialog<Color>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: suggestedColor,
            onColorChanged: (color) => _currentPickerColor = color,
            showLabel: true,
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop(_currentPickerColor);
            },
          ),
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () {
              Navigator.of(context).pop(null);
            },
          ),
        ],
      ),
    );

    if (choosenColor != null) {
      widget.onColorChanged(choosenColor);
    }
  }
}
