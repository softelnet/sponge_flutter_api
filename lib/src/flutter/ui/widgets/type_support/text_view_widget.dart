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
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/util/model_utils.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/gui_constants.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';

class TextViewWidget extends StatefulWidget {
  TextViewWidget({
    Key key,
    @required this.label,
    @required this.text,
    this.format,
    this.maxLength = -1,
    this.compact = false,
    this.showLabel = true,
  }) : super(key: key);

  final String label;
  final String text;
  final String format;
  final int maxLength;
  final bool compact;
  final bool showLabel;

  @override
  _TextViewWidgetState createState() => _TextViewWidgetState();
}

class _TextViewWidgetState extends State<TextViewWidget> {
  MarkdownBody _buildMarkdown(Key key, BuildContext context, String data) {
    var theme = Theme.of(context);
    var markdownTheme = MarkdownStyleSheet.fromTheme(theme);

    return MarkdownBody(
      key: key,
      data: data,
      styleSheet: markdownTheme.copyWith(
          code: markdownTheme.code.apply(
        color: Colors.black,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget mainWidget;
    String text = widget.maxLength > -1
        ? ModelUtils.substring(widget.text, widget.maxLength)
        : widget.text;
    var key = Key('value');

    if (text != null) {
      switch (widget.format) {
        case Formats.STRING_FORMAT_MARKDOWN:
          mainWidget = _buildMarkdown(key, context, text);
          break;
        case Formats.STRING_FORMAT_CONSOLE:
          mainWidget = _buildMarkdown(key, context, '```\n$text\n```');
          break;
      }
    }

    bool useCompact = mainWidget == null && widget.compact;
    var textValue = text ?? (useCompact ? 'None' : '');

    bool showLabel = widget.showLabel && widget.label != null;

    if (useCompact) {
      return Text(
        showLabel ? '${widget.label}: $textValue' : textValue,
        key: key,
        softWrap: true,
      );
    } else {
      mainWidget ??= Text(
        textValue,
        key: key,
        softWrap: true,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showLabel)
            Text(
              '${widget.label}',
              key: Key('label'),
              style: getArgLabelTextStyle(context),
            ),
          if (showLabel)
            Container(
              margin: EdgeInsets.all(2.0),
            ),
          FractionallySizedBox(
            widthFactor: 1,
            child: mainWidget,
          ),
        ],
      );
    }
  }
}

class ExtendedTextViewWidget extends StatefulWidget {
  ExtendedTextViewWidget({
    Key key,
    @required this.textViewer,
  }) : super(key: key);

  final TextViewWidget textViewer;

  @override
  _ExtendedTextViewWidgetState createState() => _ExtendedTextViewWidgetState();
}

class _ExtendedTextViewWidgetState extends State<ExtendedTextViewWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.textViewer.label ?? ''}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: _buldScrollContainer(widget.textViewer),
        ),
      ),
    );
  }

  Widget _buldScrollContainer(Widget child) {
    var textViewerWidth =
        (ApplicationProvider.of(context).service.settings.textViewerWidth ??
                0) *
            GuiConstants.TEXT_VIEWER_WIDTH_SCALE;

    return SingleChildScrollView(
      child: (textViewerWidth ?? 0) > 0
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                child: child,
                width: textViewerWidth.roundToDouble(),
              ),
            )
          : child,
    );
  }
}

