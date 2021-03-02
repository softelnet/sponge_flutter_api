// Copyright 2021 The Sponge authors.
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
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/mvp/widgets/type/type_type_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/unit_type_gui_providers.dart';

// TODO TypeTypeWidget - Work in progress.
class TypeTypeWidget extends StatefulWidget {
  TypeTypeWidget({
    Key key,
    @required this.editorContext,
    @required this.guiProvider,
  }) : super(key: key);

  final TypeEditorContext editorContext;
  final TypeTypeGuiProvider guiProvider;

  @override
  _TypeTypeWidgetState createState() => _TypeTypeWidgetState();
}

class _TypeTypeWidgetState extends State<TypeTypeWidget>
    implements TypeTypeView {
  TypeTypePresenter _presenter;

  @override
  Widget build(BuildContext context) {
    var model = TypeTypeViewModel(widget.editorContext);

    _presenter ??= TypeTypePresenter(model, this);

    // The model contains the UiContext so it has to be updated every build.
    _presenter.updateModel(model);

    return Column(children: <Widget>[
      TextFormField(
        decoration: InputDecoration(
          border: const UnderlineInputBorder(),
          labelText: 'Name',
        ),
        validator: (value) {
          if (value.isEmpty) {
            return 'Please enter some text';
          }
          return null;
        },
        onSaved: (value) => widget.editorContext.onSave(value),
      )
    ]);
  }
}
