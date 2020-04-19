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

import 'package:flutter/widgets.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';

class MultiChoiceListEditViewModel extends BaseViewModel {
  MultiChoiceListEditViewModel({
    @required this.qType,
    @required this.labelText,
    @required this.value,
    @required this.onGetProvidedArg,
    @required this.onSave,
    @required this.enabled,
  });

  final QualifiedDataType qType;
  final String labelText;
  final List value;
  final GetProvidedArgCallback onGetProvidedArg;
  final ValueChanged onSave;
  final bool enabled;
}

abstract class MultiChoiceListEditView extends BaseView {}

class MultiChoiceListEditPresenter extends BasePresenter<
    MultiChoiceListEditViewModel, MultiChoiceListEditView> {
  MultiChoiceListEditPresenter(ApplicationService service,
      MultiChoiceListEditViewModel model, MultiChoiceListEditView view)
      : super(service, model, view);

  @override
  FlutterApplicationService get service =>
      FlutterApplicationService.of(super.service);

  String get labelText => viewModel.labelText;
  List get value => viewModel.value;
  bool get enabled => viewModel.enabled;

  List<AnnotatedValue> _elementValueSetItems;
  List<dynamic> _elementValueSetItemsAsValues;

  List<AnnotatedValue> getElementValueSetItems() {
    ProvidedValue providedValue = viewModel.onGetProvidedArg(viewModel.qType);
    _elementValueSetItems = providedValue?.annotatedElementValueSet
            ?.where((annotatedValue) => annotatedValue != null)
            ?.toList() ??
        [];

    _elementValueSetItemsAsValues = _elementValueSetItems
        .map((annotatedValue) => annotatedValue.value)
        .toList();

    return _elementValueSetItems;
  }

  List<dynamic> get elementValueSetItemsAsValues =>
      _elementValueSetItemsAsValues;

  void updateValue(Object elementValue, bool selected) {
    if (selected) {
      if (!containsElement(elementValue)) {
        value.add(elementValue);
      }
    } else {
      value.remove(elementValue);
    }
  }

  void save() {
    // Set the list order according to the elementValueSet order.
    value.sort((v1, v2) =>
        _elementValueSetItemsAsValues.indexOf(v1) -
        _elementValueSetItemsAsValues.indexOf(v2));

    viewModel.onSave(value);
  }

  String getValueSetItemLabel(AnnotatedValue item) =>
      item.valueLabel ?? item.value;

  bool containsElement(Object elementValue) =>
      value?.contains(elementValue) ?? false;
}
