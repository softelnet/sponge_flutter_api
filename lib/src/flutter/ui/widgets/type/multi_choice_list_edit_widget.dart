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
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';

class MultiChoiceListEditWidget extends StatefulWidget {
  MultiChoiceListEditWidget({
    Key key,
    @required this.qType,
    @required this.labelText,
    @required this.value,
    @required this.onGetProvidedArg,
    @required this.onSave,
    @required this.enabled,
  }) : super(key: key);

  final QualifiedDataType qType;
  final String labelText;
  final List value;
  final GetProvidedArgCallback onGetProvidedArg;
  final ValueChanged onSave;
  final bool enabled;

  @override
  _MultiChoiceListEditWidgetState createState() =>
      _MultiChoiceListEditWidgetState();
}

class _MultiChoiceListEditWidgetState extends State<MultiChoiceListEditWidget> {
  @override
  Widget build(BuildContext context) {
    List<AnnotatedValue> elementValueSet = _getElementValueSetValues();
    var elementValueSetAsValues =
        elementValueSet.map((annotatedValue) => annotatedValue.value).toList();

    var currentValueAsSet = widget.value?.toSet() ?? {};

    return Center(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                widget.labelText ?? '',
                style: getArgLabelTextStyle(context),
              ),
            ],
          ),
          ListBody(
            children: elementValueSet.map((elementValueSetAnnotatedValue) {
              var label = elementValueSetAnnotatedValue.valueLabel ??
                  elementValueSetAnnotatedValue.value;
              return Row(
                children: <Widget>[
                  Checkbox(
                    key: Key('checkbox-$label'),
                    value: currentValueAsSet
                        .contains(elementValueSetAnnotatedValue.value),
                    onChanged: widget.enabled
                        ? (bool selected) {
                            setState(() {
                              if (selected) {
                                if (!widget.value.contains(
                                    elementValueSetAnnotatedValue.value)) {
                                  widget.value
                                      .add(elementValueSetAnnotatedValue.value);
                                }
                              } else {
                                widget.value.remove(
                                    elementValueSetAnnotatedValue.value);
                              }
                            });

                            // Set the list order according to the elementValueSet order.
                            widget.value.sort((v1, v2) =>
                                elementValueSetAsValues.indexOf(v1) -
                                elementValueSetAsValues.indexOf(v2));

                            widget.onSave(widget.value);
                          }
                        : null,
                  ),
                  Text(label),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<AnnotatedValue> _getElementValueSetValues() {
    ProvidedValue argValue = widget.onGetProvidedArg(widget.qType);
    return argValue?.annotatedElementValueSet
            ?.where((annotatedValue) => annotatedValue != null)
            ?.toList() ??
        [];
  }
}
