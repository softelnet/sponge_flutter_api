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
import 'package:sponge_flutter_api/sponge_flutter_api.dart';
import 'package:sponge_flutter_api/src/external/painter.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';

class DrawingPage extends StatefulWidget {
  DrawingPage({
    Key key,
    @required this.name,
    @required this.drawingBinary,
  }) : super(key: key);

  final String name;
  final DrawingBinaryValue drawingBinary;

  @override
  _DrawingPageState createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  PainterController _controller;

  @override
  Widget build(BuildContext context) {
    var service = ApplicationProvider.of(context).service;

    _controller ??= PainterController()
      ..strokeUpdateDeltaThresholdRatio =
          service.settings.drawingStrokeUpdateDeltaThresholdRatio;

    return WillPopScope(
      child: Scaffold(
        appBar: MediaQuery.of(context).orientation == Orientation.portrait
            ? AppBar(
                title: widget.name != null
                    ? Tooltip(
                        message: widget.name,
                        child: Text('Draw: ${widget.name}'),
                      )
                    : Text('Drawing'),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: AspectRatio(
              aspectRatio: widget.drawingBinary.aspectRatio,
              child: ConstrainedBox(
                constraints: BoxConstraints.expand(),
                child: Card(
                  elevation: 10.0,
                  margin: EdgeInsets.all(10.0),
                  child: PainterPanel(
                    drawingBinary: widget.drawingBinary,
                    controller: _controller,
                  ),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.clear),
          onPressed: () => setState(() => _controller.clear()),
          tooltip: 'Clear drawing',
        ),
      ),
      onWillPop: () async {
        try {
          _close();
        } catch (e) {
          await handleError(context, e);
        }

        return false;
      },
    );
  }

  void _close() {
    Navigator.pop(
        context,
        DrawingBinaryValue.copyWith(
          widget.drawingBinary,
          displaySize: convertToSize(_controller.size),
          strokes: convertToStrokes(_controller.strokes),
        ));
  }
}

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
