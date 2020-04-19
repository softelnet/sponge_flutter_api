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
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/mvp/widgets/type/multi_choice_list_edit_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';

class MultiChoiceListEditWidget extends StatefulWidget {
  MultiChoiceListEditWidget({
    Key key,
    @required this.viewModel,
  }) : super(key: key);

  final MultiChoiceListEditViewModel viewModel;

  @override
  _MultiChoiceListEditWidgetState createState() =>
      _MultiChoiceListEditWidgetState();
}

class _MultiChoiceListEditWidgetState extends State<MultiChoiceListEditWidget>
    implements MultiChoiceListEditView {
  MultiChoiceListEditPresenter _presenter;

  @override
  Widget build(BuildContext context) {
    _presenter ??= MultiChoiceListEditPresenter(
        ApplicationProvider.of(context).service, widget.viewModel, this);
    _presenter.updateModel(widget.viewModel);

    List<AnnotatedValue> elementValueSet = _presenter.getElementValueSetItems();

    return Center(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                _presenter.labelText ?? '',
                style: getArgLabelTextStyle(context),
              ),
            ],
          ),
          ListBody(
            children: elementValueSet.map((AnnotatedValue item) {
              var label = _presenter.getValueSetItemLabel(item);
              return Row(
                children: <Widget>[
                  Checkbox(
                    key: Key('checkbox-$label'),
                    value: _presenter.containsElement(item.value),
                    onChanged: _presenter.enabled
                        ? (bool selected) {
                            setState(() {
                              _presenter.updateValue(item.value, selected);
                            });

                            _presenter.save();
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
}
