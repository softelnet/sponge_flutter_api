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

import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';
import 'package:sponge_flutter_api/src/common/util/type_gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';

class ListTypeViewModel extends BaseViewModel {
  ListTypeViewModel(this.uiContext);

  final UiContext uiContext;
}

abstract class ListTypeView extends BaseView {
  void refresh();
}

class ListTypePresenter extends BasePresenter<ListTypeViewModel, ListTypeView> {
  ListTypePresenter(ListTypeViewModel model, ListTypeView view)
      : super(model.uiContext.service, model, view);

  bool _fetchingData = false;
  bool get fetchingData => _fetchingData;

  @override
  FlutterApplicationService get service =>
      FlutterApplicationService.of(super.service);

  UiContext get uiContext => viewModel.uiContext;

  bool get isPageable =>
      uiContext.features[Features.PROVIDE_VALUE_PAGEABLE] ?? false;

  int get pageableOffset => uiContext.features[Features.PROVIDE_VALUE_OFFSET];

  int get pageableLimit => uiContext.features[Features.PROVIDE_VALUE_LIMIT];

  int get pageableCount => uiContext.features[Features.PROVIDE_VALUE_COUNT];

  List getData() => isPageable
      ? (uiContext.callbacks.getPageableList(uiContext.qualifiedType) ??
          PageableList())
      : (uiContext.value as List ?? []);

  String createFeatureKey() =>
      uiContext.callbacks.getKey(uiContext.features[Features.KEY]);

  ListType get listType => uiContext.qualifiedType.type as ListType;

  dynamic get rawListValue =>
      uiContext.callbacks.getRawValue(uiContext.qualifiedType.path);

  DataType get elementType => listType.elementType;

  QualifiedDataType createElementQualifiedType() =>
      uiContext.qualifiedType.createChild(elementType);

  String get label => uiContext.getDecorationLabel();

  bool hasListScroll() => DataTypeGuiUtils.hasListTypeScroll(listType);

  PageableList get pageableList =>
      uiContext.callbacks.getPageableList(uiContext.qualifiedType);

  bool get isRefreshEnabled =>
      uiContext?.qualifiedType?.type?.provided != null &&
      (uiContext?.features[Features.REFRESHABLE] ?? false);

  Future<void> getMoreData() async {
    if (pageableList.hasMorePages) {
      if (!_fetchingData) {
        _fetchingData = true;
        view.refresh();

        try {
          await uiContext.callbacks
              .fetchPageableListPage(uiContext.qualifiedType);
        } finally {
          _fetchingData = false;
          view.refresh();
        }
      }
    }
  }

  bool get enabled => uiContext.enabled;

  Future<void> onRefresh() async {
    await uiContext?.callbacks?.onRefreshArgs();
  }
}
