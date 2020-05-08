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
import 'package:sponge_flutter_api/src/flutter/ui/mvp/widgets/type/map_type_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type_support/text_view_widget.dart';

// Supports only viewing.
class MapTypeWidget extends StatefulWidget {
  MapTypeWidget({Key key, this.uiContext}) : super(key: key);

  final UiContext uiContext;

  @override
  _MapTypeWidgetState createState() => _MapTypeWidgetState();
}

class _MapTypeWidgetState extends State<MapTypeWidget> implements MapTypeView {
  MapTypePresenter _presenter;

  final margin = EdgeInsets.all(5);

  @override
  Widget build(BuildContext context) {
    var model = MapTypeViewModel(widget.uiContext);

    _presenter ??= MapTypePresenter(model, this);

    // The model contains the UiContext so it has to be updated every build.
    _presenter.updateModel(model);

    String label = _presenter.label;
    String keyLabel = _presenter.keyLabel;
    String valueLabel = _presenter.valueLabel;
    Map valueMap = _presenter.valueMap;

    MapType type = _presenter.type;

    // Return widget for a null map in the read only mode.
    if (valueMap == null) {
      return TextViewWidget(
        label: label,
        text: null,
        compact: true,
      );
    }

    final TextStyle headerTextStyle = Theme.of(context).textTheme.bodyText1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null)
          Padding(
            child: Text(
              label,
              style: getArgLabelTextStyle(context),
            ),
            padding: EdgeInsets.symmetric(vertical: 10),
          ),
        Table(
          border: TableBorder.all(
            color: getBorderColor(widget.uiContext.context),
          ),
          columnWidths: {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
          children: [
            if (keyLabel != null && valueLabel != null)
              TableRow(children: [
                Container(
                  margin: margin,
                  child: Text(
                    keyLabel,
                    style: headerTextStyle,
                  ),
                ),
                Container(
                  margin: margin,
                  child: Text(
                    valueLabel,
                    style: headerTextStyle,
                  ),
                ),
              ]),
            ...valueMap.keys.toList().asMap().entries.map<TableRow>((entry) {
              var index = entry.key;
              var key = entry.value;
              var keyContext = TypeViewerContext(
                '${widget.uiContext.name}-key-$index',
                context,
                widget.uiContext.callbacks,
                widget.uiContext.qualifiedType.createChild(type.keyType),
                key,
                showLabel: false,
                loading: widget.uiContext.loading,
              );

              var valueContext = TypeViewerContext(
                '${widget.uiContext.name}-value-$index',
                context,
                widget.uiContext.callbacks,
                widget.uiContext.qualifiedType.createChild(type.valueType),
                valueMap[key],
                showLabel: false,
                loading: widget.uiContext.loading,
              );

              return TableRow(
                children: [
                  Container(
                    margin: margin,
                    child: widget.uiContext.typeGuiProviderRegistry
                        .getProvider(type.keyType)
                        .createViewer(keyContext),
                  ),
                  Container(
                    margin: margin,
                    child: widget.uiContext.typeGuiProviderRegistry
                        .getProvider(type.valueType)
                        .createViewer(valueContext),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}
