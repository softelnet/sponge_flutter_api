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
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/compatibility/compatibility_mobile.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/drawing_painter.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/external/painter.dart';
import 'package:sponge_flutter_api/src/type/type_value.dart';

// TODO Move to edit_widgets
class DrawingPage extends StatefulWidget {
  DrawingPage({
    Key key,
    @required this.name,
    @required this.drawingBinary,
  }) : super(key: key);

  final String name;
  final DrawingBinaryValue drawingBinary;

  @override
  createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  PainterController _controller;

  Widget build(BuildContext context) {
    var service = ApplicationProvider.of(context).service;

    _controller ??= PainterController()
      ..strokeUpdateDeltaThresholdRatio =
          service.settings.drawingStrokeUpdateDeltaThresholdRatio
      ..isAntiAlias = service.settings.drawAntiAliasing;

    return WillPopScope(
      child: Scaffold(
        appBar: MediaQuery.of(context).orientation == Orientation.portrait
            ? AppBar(title: Text('Draw: ${widget.name ?? ''}'))
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
    // TODO Changing the main reference and then returning it.
    widget.drawingBinary
      ..displaySize = convertToSize(_controller.size)
      ..strokes = convertToStrokes(_controller.strokes);

    Navigator.pop(context, widget.drawingBinary);
  }
}
