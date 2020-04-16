// Copyright 2019 The Sponge authors.
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
//
//
// The code in this file is a modified library https://pub.dartlang.org/packages/painter2 (released under the MIT licenses).
// It is used by the `BinaryTypeGuiProvider` for drawings.
//
//
// The original license:
// "MIT License

// Copyright (c) 2019 Javi Hurtado

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE."
//
//
// The modifications include:
// * A callback that is to be called when a stroke ends (`StrokeEndCallback`).
// * Strokes are kept also as lists of offsets (`_strokes`, `_undoneStrokes`) to allow drawing paths as separated lines
//   (in the `usePaths` flag is set). In some cases a drawing will look nicer if this flag is set.
// * The `useSubpaths` flag, if set, forces drawing sub-pahts instead of one path for a single stroke.  If `useSubpaths`
//   is `true`, a drawing creates round edges if stroke lines are wide. In some cases a drawing will look nicer
//   if this flag is set.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart' as mat show Image;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Image;

typedef StrokeEndCallback = FutureOr Function();

class Painter extends StatefulWidget {
  Painter(
    PainterController painterController, {
    this.onStrokeEnd,
  })  : painterController = painterController,
        super(key: ValueKey<PainterController>(painterController));

  final PainterController painterController;
  final StrokeEndCallback onStrokeEnd;

  @override
  _PainterState createState() => _PainterState();
}

class _PainterState extends State<Painter> {
  final _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.painterController._globalKey = _globalKey;
  }

  @override
  Widget build(BuildContext context) {
    Widget child = CustomPaint(
      willChange: true,
      painter: _PainterPainter(
        widget.painterController._pathHistory,
        repaint: widget.painterController,
      ),
    );
    child = ClipRect(child: child);
    if (widget.painterController.backgroundImage == null) {
      child = RepaintBoundary(
        key: _globalKey,
        child: GestureDetector(
          child: child,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
        ),
      );
    } else {
      child = RepaintBoundary(
        key: _globalKey,
        child: Stack(
          alignment: FractionalOffset.center,
          fit: StackFit.expand,
          children: <Widget>[
            widget.painterController.backgroundImage,
            GestureDetector(
              child: child,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
            )
          ],
        ),
      );
    }
    return Container(
      child: child,
      width: double.infinity,
      height: double.infinity,
    );
  }

  void _onPanStart(DragStartDetails start) {
    Offset pos = (context.findRenderObject() as RenderBox)
        .globalToLocal(start.globalPosition);
    widget.painterController._pathHistory.add(pos);
    widget.painterController._notifyListeners();
  }

  void _onPanUpdate(DragUpdateDetails update) {
    var renderBox = context.findRenderObject() as RenderBox;

    Offset pos = renderBox.globalToLocal(update.globalPosition);
    Offset prev = widget.painterController._pathHistory.strokes.last.last;
    Offset delta = pos - prev;

    var thresholdSquared =
        widget.painterController.strokeUpdateDeltaThresholdSquared;

    if (thresholdSquared == 0 || delta.distanceSquared < thresholdSquared) {
      // print(
      //     'update: $pos, delta: $delta, box: ${renderBox.size}, threshold: ${sqrt(thresholdSquared)}');
      widget.painterController._pathHistory.updateCurrent(pos);
      widget.painterController._notifyListeners();
    }
  }

  void _onPanEnd(DragEndDetails end) {
    widget.painterController._pathHistory.endCurrent();
    widget.painterController._notifyListeners();

    if (widget.onStrokeEnd != null) {
      widget.onStrokeEnd();
    }
  }
}

class _PainterPainter extends CustomPainter {
  _PainterPainter(
    this._path, {
    Listenable repaint,
  }) : super(repaint: repaint);

  final _PathHistory _path;

  @override
  void paint(Canvas canvas, Size size) {
    _path.draw(canvas, size);
  }

  @override
  bool shouldRepaint(_PainterPainter oldDelegate) => true;
}

class _PathEntry {
  _PathEntry(this.path, this.paint);
  Path path;
  Paint paint;
}

class _PathHistory {
  _PathHistory();
  final _paths = <_PathEntry>[];
  final _strokes = <List<Offset>>[];
  final _undone = <_PathEntry>[];
  final _undoneStrokes = <List<Offset>>[];
  Paint currentPaint;
  final _backgroundPaint = Paint();
  bool _inDrag = false;
  bool usePaths = true;
  // If `useSubpaths` is `true`, a drawing creates round edges if stroke lines are wide.
  bool useSubpaths = true;

  List<List<Offset>> get strokes => _strokes;

  bool canUndo() => _paths.isNotEmpty;

  void undo() {
    if (!_inDrag && canUndo()) {
      _undone.add(_paths.removeLast());
      _undoneStrokes.add(_strokes.removeLast());
    }
  }

  bool canRedo() => _undone.isNotEmpty;

  void redo() {
    if (!_inDrag && canRedo()) {
      _paths.add(_undone.removeLast());
      _strokes.add(_undoneStrokes.removeLast());
    }
  }

  void clear() {
    if (!_inDrag) {
      _paths.clear();
      _strokes.clear();
      _undone.clear();
      _undoneStrokes.clear();
    }
  }

  set backgroundColor(color) => _backgroundPaint.color = color;

  void add(Offset startPoint) {
    if (!_inDrag) {
      _inDrag = true;
      var path = Path();

      path.moveTo(startPoint.dx, startPoint.dy);
      _paths.add(_PathEntry(path, currentPaint));
      _strokes.add([Offset(startPoint.dx, startPoint.dy)]);
    }
  }

  void updateCurrent(Offset nextPoint) {
    if (_inDrag) {
      Path path = _paths.last.path;
      if (_strokes.last.length > 1 && useSubpaths) {
        // A drawing creates round edges if stroke lines are wide.
        path.moveTo(_strokes.last.last.dx, _strokes.last.last.dy);
      }
      path.lineTo(nextPoint.dx, nextPoint.dy);

      _strokes.last.add(nextPoint);
    }
  }

  void endCurrent() {
    _inDrag = false;
  }

  void normalizePaint() {
    _paths.forEach((path) => path.paint = currentPaint);
  }

  void draw(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0.0, 0.0, size.width, size.height), _backgroundPaint);

    // Draw by using pahts or separate lines.
    if (usePaths) {
      _paths.asMap().forEach((index, path) {
        if (_strokes[index].length == 1) {
          // Draw a single point as a point, not a path to mitigate some problems on some devices.
          canvas.drawPoints(PointMode.points, _strokes[index], path.paint);
        } else {
          canvas.drawPath(path.path, path.paint);
        }
      });
    } else {
      _strokes.forEach((stroke) {
        for (var i = 0; i < stroke.length - 1; i++) {
          canvas.drawLine(stroke[i], stroke[i + 1], currentPaint);
        }
      });
    }
  }
}

class PainterController extends ChangeNotifier {
  static const double DEFAULT_STROKE_UPDATE_DELTA_THRESHOLD_RATIO = 0.15;

  Color _drawColor = Color.fromARGB(255, 0, 0, 0);
  Color _backgroundColor = Color.fromARGB(255, 255, 255, 255);
  mat.Image _bgimage;
  double _thickness = 1.0;
  final _pathHistory = _PathHistory();
  GlobalKey _globalKey;
  Size _size;

  bool isAntiAlias = true;
  double useSubpathsStrokeWidthRatioThreshold = 0.05;

  double _strokeUpdateDeltaThresholdRatio =
      DEFAULT_STROKE_UPDATE_DELTA_THRESHOLD_RATIO;

  double _strokeUpdateDeltaThresholdSquaredCached;

  double get strokeUpdateDeltaThresholdSquared {
    if (_size == null) {
      return 0;
    }

    _strokeUpdateDeltaThresholdSquaredCached ??=
        pow(_size.longestSide * _strokeUpdateDeltaThresholdRatio, 2);

    return _strokeUpdateDeltaThresholdSquaredCached;
  }

  set strokeUpdateDeltaThresholdRatio(double value) {
    _strokeUpdateDeltaThresholdRatio = value;
    _strokeUpdateDeltaThresholdSquaredCached = null;
  }

  Size get size => _size;
  set size(Size value) {
    // Rescale if the size changes.
    if (_size != null && _size != value) {
      double xScale = value.width / _size.width;
      double xycale = value.height / _size.height;

      var newStrokes = strokes
          .map((stroke) => List.generate(stroke.length, (i) {
                Offset point = stroke[i];
                return point != null ? point.scale(xScale, xycale) : null;
              }))
          .toList();

      _pathHistory.clear();
      addStrokes(newStrokes);

      _strokeUpdateDeltaThresholdSquaredCached = null;
    }

    _size = value;
  }

  Color get drawColor => _drawColor;
  set drawColor(Color color) {
    _drawColor = color;
    _updatePaint();
  }

  Color get backgroundColor => _backgroundColor;
  set backgroundColor(Color color) {
    _backgroundColor = color;
    _updatePaint();
  }

  mat.Image get backgroundImage => _bgimage;
  set backgroundImage(mat.Image image) {
    _bgimage = image;
    _updatePaint();
  }

  double get thickness => _thickness;
  set thickness(double t) {
    _thickness = t;
    _updatePaint();
  }

  set globalThickness(double t) {
    _thickness = t;
    _updatePaint(doNotifyListeners: false);
    _pathHistory.normalizePaint();
    notifyListeners();
  }

  void addStrokes(List<List<Offset>> strokes) {
    strokes
        .where((stroke) => stroke.isNotEmpty)
        .forEach((stroke) => _addStroke(stroke));
    notifyListeners();
  }

  void _addStroke(List<Offset> stroke) {
    _pathHistory.add(stroke[0]);
    stroke.skip(1).forEach((point) => _pathHistory.updateCurrent(point));
    _pathHistory.endCurrent();
  }

  List<List<Offset>> get strokes => _pathHistory.strokes;

  void _updatePaint({bool doNotifyListeners = true}) {
    _pathHistory.currentPaint = Paint()
      ..color = drawColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..isAntiAlias = isAntiAlias
      ..strokeCap = StrokeCap.round;
    _pathHistory.backgroundColor =
        _bgimage != null ? Color(0x00000000) : _backgroundColor;
    _pathHistory..useSubpaths = usingSubpaths;

    if (doNotifyListeners) {
      notifyListeners();
    }
  }

  bool get usingSubpaths => size != null
      ? thickness / size.width > useSubpathsStrokeWidthRatioThreshold
      : true;

  void undo() {
    _pathHistory.undo();
    notifyListeners();
  }

  void redo() {
    _pathHistory.redo();
    notifyListeners();
  }

  bool get canUndo => _pathHistory.canUndo();
  bool get canRedo => _pathHistory.canRedo();

  void _notifyListeners() {
    notifyListeners();
  }

  void clear() {
    _pathHistory.clear();
    notifyListeners();
  }

  void draw(Canvas canvas, Size size) {
    _pathHistory.draw(canvas, size);
  }

  Future<Uint8List> exportAsPngBytes() async {
    RenderRepaintBoundary boundary =
        _globalKey.currentContext.findRenderObject();
    var image = await boundary.toImage();
    var byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData.buffer.asUint8List();
  }
}
