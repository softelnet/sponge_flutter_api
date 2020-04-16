// Copyright 2018 The Sponge authors.
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
import 'package:sponge_flutter_api/src/common/model/type/type_value.dart';
import 'package:sponge_flutter_api/src/external/painter.dart';
import 'package:sponge_flutter_api/src/flutter/compatibility/compatibility_flutter.dart';

class PainterPanel extends StatefulWidget {
  PainterPanel({
    Key key,
    @required this.drawingBinary,
    @required this.controller,
    this.onStrokeEnd,
  }) : super(key: key);

  final PainterController controller;
  final DrawingBinaryValue drawingBinary;
  final StrokeEndCallback onStrokeEnd;

  @override
  _PainterPanelState createState() => _PainterPanelState();
}

class _PainterPanelState extends State<PainterPanel> {
  PainterController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();

    _controller
      ..drawColor = convertFromColor(widget.drawingBinary.color)
      ..backgroundColor = convertFromColor(widget.drawingBinary.background)
      ..addStrokes(convertFromStrokes(widget.drawingBinary.strokes));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        var currentSize = Size(constraints.maxWidth, constraints.maxHeight);

        _controller
          ..size = currentSize
          ..globalThickness =
              currentSize.width * widget.drawingBinary.strokeWidthRatio;

        return Painter(
          _controller,
          onStrokeEnd: widget.onStrokeEnd,
        );
      },
    );
  }
}
