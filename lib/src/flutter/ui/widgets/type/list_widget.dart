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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/util/type_gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/unit_type_gui_providers.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/model_gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type_support/sub_actions.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/widgets.dart';

class ListTypeWidget extends StatefulWidget {
  ListTypeWidget({
    Key key,
    @required this.uiContext,
    @required this.guiProvider,
    this.useScrollableIndexedList = false,
  }) : super(key: key);

  final UiContext uiContext;
  final ListTypeGuiProvider guiProvider;
  final bool useScrollableIndexedList;

  @override
  _ListTypeWidgetState createState() => _ListTypeWidgetState();
}

class _ListTypeWidgetState extends State<ListTypeWidget> {
  SubActionsController _subActionsController;

  ScrollController _scrollController;
  ItemScrollController _itemScrollController;
  ItemPositionsListener _itemPositionsListener;

  bool _fetchingData = false;
  final _itemMargin = 1.0;
  String _lastFeatureKey;

  final _lastListWidgetKey = GlobalKey();
  double _lastListWidgetHeight;
  double get lastListWidgetHeight {
    if (_lastListWidgetHeight == null) {
      final renderBox = _lastListWidgetKey.currentContext?.findRenderObject();
      _lastListWidgetHeight =
          renderBox is RenderBox ? renderBox.size?.height : null;
    }

    return _lastListWidgetHeight;
  }

  FlutterApplicationService get service => widget.uiContext.service;

  bool get isPageable =>
      widget.uiContext.features[Features.PROVIDE_VALUE_PAGEABLE] ?? false;

  int get pageableOffset =>
      widget.uiContext.features[Features.PROVIDE_VALUE_OFFSET];

  int get pageableLimit =>
      widget.uiContext.features[Features.PROVIDE_VALUE_LIMIT];

  int get pageableCount =>
      widget.uiContext.features[Features.PROVIDE_VALUE_COUNT];

  void _setupScrollController() {
    var featureKey = _createFeatureKey();
    var isFeatureKeyChanged = featureKey != null &&
        _lastFeatureKey != null &&
        _lastFeatureKey != featureKey;

    if (widget.useScrollableIndexedList) {
      if (_itemScrollController == null || isFeatureKeyChanged) {
        _itemScrollController = ItemScrollController();
        _itemPositionsListener = ItemPositionsListener.create();

        _itemPositionsListener.itemPositions.addListener(_onScroll);
      }
    } else {
      if (_scrollController == null || isFeatureKeyChanged) {
        _scrollController = ScrollController();
        _scrollController.addListener(_onScroll);
      }
    }

    _lastFeatureKey = featureKey;
  }

  bool _shouldGetMoreDataByScroll() {
    if (widget.useScrollableIndexedList) {
      var data = _getData();
      var positions = List.of(_itemPositionsListener.itemPositions.value);

      if (positions.isNotEmpty) {
        var lastPosition =
            positions.map((position) => position.index).reduce(max);
        if (lastPosition == data.length) {
          return true;
        }
      }
    } else {
      // print(
      //     'position.pixels= ${_scrollController.position.pixels}, maxScrollExtent=${_scrollController.position.maxScrollExtent}');

      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        return true;
      }

      // Defer calculation of `lastListWidgetHeight`.
      if (lastListWidgetHeight != null &&
          _scrollController.position.pixels >
              _scrollController.position.maxScrollExtent -
                  lastListWidgetHeight) {
        return true;
      }
    }

    return false;
  }

  // double _getLastListWidgetHeight() {
  //   final renderBox = _lastListWidgetKey.currentContext?.findRenderObject();
  //   return renderBox is RenderBox ? renderBox.size?.height : null;
  // }

  void _onScroll() {
    if (_shouldGetMoreDataByScroll()) {
      _getMoreData();
    }
  }

  void _tryGetMoreData() {
    _onScroll();
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  List _getData() => isPageable
      ? (widget.uiContext.callbacks
              .getPageableList(widget.uiContext.qualifiedType) ??
          PageableList())
      : (widget.uiContext.value as List ?? []);

  String _createFeatureKey() => widget.uiContext.callbacks
      .getKey(widget.uiContext.features[Features.KEY]);

  PageStorageKey _createListKey() {
    var featureKey = _createFeatureKey();

    // Both list implementations must have diffrent keys.
    return PageStorageKey(
        '${widget.uiContext.name}-${widget.uiContext.qualifiedType.path}-${widget.useScrollableIndexedList ? "indexed" : "standard"}-${featureKey != null ? "-" + featureKey : ""}');
  }

  @override
  Widget build(BuildContext context) {
    var data = _getData();

    if (isPageable) {
      _setupScrollController();

      WidgetsBinding.instance.addPostFrameCallback((_) => _tryGetMoreData());
    }

    var elementType = widget.guiProvider.type.elementType;

    _subActionsController =
        SubActionsController.forList(widget.uiContext, service.spongeService);

    var buttons = <Widget>[];

    if (_subActionsController.isCreateEnabled()) {
      // TODO Support active/inactive verification to enable/disable the button.
      buttons.add(FlatButton(
        key: Key('list-create'),
        child: getActionIconByActionName(
              context,
              service,
              _subActionsController.getCreateActionName(),
            ) ??
            Icon(
              Icons.add,
              color: getIconColor(context),
            ),
        padding: EdgeInsets.zero,
        onPressed: () => _subActionsController
            .onCreateElement(context)
            .catchError((e) => handleError(context, e)),
      ));
    }

    if (_isRefreshEnabled) {
      buttons.add(FlatButton(
        key: Key('list-refresh'),
        child: Icon(
          Icons.refresh,
          color: getIconColor(context),
        ),
        padding: EdgeInsets.zero,
        onPressed: () => _refresh().catchError((e) => handleError(context, e)),
      ));
    }

    if (_isIndicatedIndexEnabled) {
      buttons.add(FlatButton(
        key: Key('list-goToIndicatedIndex'),
        child: Icon(
          MdiIcons.target,
          color: getIconColor(context),
        ),
        padding: EdgeInsets.zero,
        onPressed: () =>
            _goToIndicatedItem().catchError((e) => handleError(context, e)),
      ));
    }

    var qElementType = widget.uiContext.qualifiedType.createChild(elementType);

    var label = widget.uiContext.getDecorationLabel();

    const listPadding = EdgeInsets.only(bottom: 5);

    var isListScroll =
        DataTypeGuiUtils.hasListTypeScroll(widget.uiContext.qualifiedType.type);

    var itemBuilder = (BuildContext context, int index) {
      if (index == data.length) {
        return _buildProgressIndicator();
      }

      // TODO Why is this required when switched to ScrollablePositionedList from ListView?
      return index < data.length
          ? _createElementWidget(index, qElementType, data[index])
          : Container();
    };

    var separatorBuilder =
        (BuildContext context, int index) => Container(height: _itemMargin);
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Padding(
              child: Text(
                label ?? '',
                style: getArgLabelTextStyle(context),
              ),
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            Expanded(
              child: ButtonBar(
                children: buttons,
                buttonPadding: EdgeInsets.zero,
                alignment: MainAxisAlignment.end,
              ),
            ),
          ],
        ),
        isListScroll
            ? Expanded(
                child: Padding(
                  padding: listPadding,
                  child: PageStorageConsumer(
                    child: widget.useScrollableIndexedList
                        ? ScrollablePositionedList.separated(
                            key: _createListKey(),
                            itemScrollController:
                                isPageable ? _itemScrollController : null,
                            itemPositionsListener:
                                isPageable ? _itemPositionsListener : null,
                            itemCount: data.length + 1,
                            itemBuilder: itemBuilder,
                            separatorBuilder: separatorBuilder,
                            padding: EdgeInsets.zero,
                          )
                        : ListView.separated(
                            key: _createListKey(),
                            controller: isPageable ? _scrollController : null,
                            //shrinkWrap: true,
                            itemCount: data.length + 1,
                            itemBuilder: itemBuilder,
                            separatorBuilder: separatorBuilder,
                            padding: EdgeInsets.zero,
                          ),
                  ),
                ),
              )
            : Padding(
                padding: listPadding,
                child: ListBody(
                  children: data
                      .asMap()
                      .map((index, element) => MapEntry(
                          index,
                          _createElementWidget(index, qElementType, element,
                              verticalMargin: _itemMargin)))
                      .values
                      .toList(),
                ),
              ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      key: _lastListWidgetKey,
      padding: const EdgeInsets.all(5),
      child: Center(
        child: Opacity(
          opacity: _fetchingData ? 1 : 0,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Future<void> _getMoreData() async {
    var pageableList = widget.uiContext.callbacks
        .getPageableList(widget.uiContext.qualifiedType);

    if (pageableList.hasMorePages) {
      if (!_fetchingData) {
        setState(() {
          _fetchingData = true;
        });

        try {
          await widget.uiContext.callbacks
              .fetchPageableListPage(widget.uiContext.qualifiedType);
        } finally {
          setState(() {
            _fetchingData = false;
          });
        }
      }
    }
  }

  Widget _createElementCard(Widget child, {double verticalMargin}) {
    return Card(
      margin: verticalMargin != null
          ? EdgeInsets.only(bottom: verticalMargin)
          : EdgeInsets.zero,
      shape: BeveledRectangleBorder(),
      child: child,
    );
  }

  Widget _createElementWidget(
    int index,
    QualifiedDataType qElementType,
    dynamic element, {
    double verticalMargin,
  }) {
    var subUiContext = TypeViewerContext(
      widget.uiContext.name,
      context,
      widget.uiContext.callbacks,
      qElementType,
      element,
      showLabel: false,
      loading: widget.uiContext.loading,
    );

    var elementTypeProvider = widget.guiProvider.getElementTypeProvider();

    var elementIconInfo = Features.getIcon(subUiContext.features);

    return _createElementCard(
      ListTile(
        key: Key('list-element-$index'),
        leading: getIcon(context, service, elementIconInfo),
        title: elementTypeProvider.createCompactViewer(subUiContext),
        subtitle: subUiContext.valueDescription != null
            ? Text(subUiContext.valueDescription)
            : null,
        trailing: _subActionsController.hasSubActions(element) &&
                widget.uiContext.enabled
            ? SubActionsWidget.forListElement(
                subUiContext,
                service.spongeService,
                controller: _subActionsController,
                element: element,
                index: index,
                header: subUiContext.valueLabel != null
                    ? Text(subUiContext.valueLabel)
                    : null,
              )
            : null,

        //Icon(Icons.more_vert),
        dense: true,
        //contentPadding: EdgeInsets.all(0),
        onTap: widget.uiContext.enabled && _isOnElementTap(element)
            ? () => _onElementTap(subUiContext, element, index)
                .catchError((e) => handleError(context, e))
            : null,
        contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      ),
      verticalMargin: verticalMargin,
    );
  }

  bool _isOnActivateSubmit(dynamic rawElement) =>
      _subActionsController
          .getFeatures(rawElement)[Features.SUB_ACTION_ACTIVATE_ACTION] ==
      Features.TYPE_LIST_ACTIVATE_ACTION_VALUE_SUBMIT;

  bool _isOnElementTap(dynamic rawElement) =>
      _isOnActivateSubmit(rawElement) ||
      _subActionsController.isActivateEnabled(rawElement) ||
      service.settings.argumentListElementTapBehavior == 'update' &&
          _subActionsController.isUpdateEnabled(rawElement) ||
      _subActionsController.isReadEnabled(rawElement);

  Future<void> _onElementTap(
      TypeViewerContext subUiContext, dynamic rawElement, int index) async {
    if (_isOnActivateSubmit(rawElement)) {
      subUiContext.callbacks.onActivate(subUiContext.qualifiedType, rawElement);
    } else if (_subActionsController.isActivateEnabled(rawElement)) {
      await _subActionsController.onActivateElement(context, rawElement,
          index: index);
    } else if (service.settings.argumentListElementTapBehavior == 'update' &&
        _subActionsController.isUpdateEnabled(rawElement)) {
      await _subActionsController.onUpdateElement(context, rawElement,
          index: index);
    } else if (_subActionsController.isReadEnabled(rawElement)) {
      await _subActionsController.onReadElement(context, rawElement,
          index: index);
    }
  }

  bool get _isRefreshEnabled =>
      widget.uiContext?.qualifiedType?.type?.provided != null &&
      (widget.uiContext?.features[Features.REFRESHABLE] ?? false);

  bool get _isIndicatedIndexEnabled {
    var data = _getData();

    return widget.useScrollableIndexedList &&
        data is PageableList &&
        data.indicatedIndex != null &&
        data.indicatedIndex < data.length;
  }

  Future<void> _refresh() async {
    await widget.uiContext?.callbacks?.onRefreshArgs();
  }

  Future<void> _goToIndicatedItem() async {
    var data = _getData();

    if (data is PageableList &&
        data.indicatedIndex != null &&
        data.indicatedIndex < data.length) {
      _itemScrollController?.jumpTo(index: data.indicatedIndex);
    }
  }
}
