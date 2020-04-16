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

class SliderWidget extends StatefulWidget {
  SliderWidget({
    Key key,
    @required this.name,
    @required this.initialValue,
    @required this.minValue,
    @required this.maxValue,
    @required this.onValueChanged,
    this.responsive = false,
    this.enabled = true,
  }) : super(key: key);

  final String name;
  final int initialValue;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onValueChanged;
  final bool responsive;
  final bool enabled;

  @override
  _SliderWidgetState createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget> {
  int _value;
  bool _changingByUi = false;

  @override
  Widget build(BuildContext context) {
    if (_value == null || !_changingByUi || widget.responsive) {
      _value = widget.initialValue;
    }

    return Slider(
      activeColor: Theme.of(context).accentColor,
      label: widget.name,
      min: widget.minValue.roundToDouble(),
      max: widget.maxValue.roundToDouble(),
      value: _value?.roundToDouble() ?? widget.minValue.roundToDouble(),
      onChanged: widget.enabled
          ? (value) async {
              if (!widget.responsive) {
                _changingByUi = true;
                setState(() {
                  _value = value.toInt();
                });
              } else {
                widget.onValueChanged(value?.toInt());
              }
            }
          : null,
      onChangeEnd: (value) async {
        if (!widget.responsive) {
          _changingByUi = false;
          widget.onValueChanged(value?.toInt());
        }
      },
    );
  }
}
