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

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/unit_type_gui_providers.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/edit/sub_actions.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/error_widgets.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/view_widgets.dart';
import 'package:sponge_flutter_api/src/util/utils.dart';

class OptionalScrollContainer extends InheritedWidget {
  OptionalScrollContainer({
    Key key,
    @required this.scrollable,
    @required Widget child,
  }) : super(key: key, child: child);

  final bool scrollable;

  @override
  bool updateShouldNotify(OptionalScrollContainer old) => true;

  static OptionalScrollContainer of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OptionalScrollContainer>();
}

class OptionalExpanded extends StatelessWidget {
  OptionalExpanded({
    Key key,
    @required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return (OptionalScrollContainer.of(context)?.scrollable ?? true)
        ? child
        : Expanded(child: child);
  }
}

class RecordTypeWidget extends StatefulWidget {
  RecordTypeWidget({
    Key key,
    @required this.uiContext,
  }) : super(key: key) {
    Validate.isTrue(
        uiContext.qualifiedType.type is RecordType, 'Record type expected');
  }

  final UiContext uiContext;

  @override
  _RecordTypeWidgetState createState() => _RecordTypeWidgetState();
}

class _RecordTypeWidgetState extends State<RecordTypeWidget> {
  Map<String, TypeGuiProvider> _typeGuiProviders;
  bool _isExpanded;

  bool get isRecordReadOnly => widget.uiContext.readOnly;

  bool get isRecordEnabled => widget.uiContext.enabled;

  bool _hasRootRecordSingleLeadingField() {
    var thisLeadingFieldPath = DataTypeGuiUtils.getRootRecordSingleLeadingField(
            widget.uiContext.qualifiedType, widget.uiContext.value as Map)
        ?.qType
        ?.path;

    return widget.uiContext.rootRecordSingleLeadingField != null &&
        widget.uiContext.rootRecordSingleLeadingField == thisLeadingFieldPath;
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (_hasRootRecordSingleLeadingField()) {
        return _buildFieldsWidgets(context)[0];
      } else {
        return _build(context);
      }
    } catch (e) {
      return Center(
        child: NotificationPanelWidget(
          notification: e,
          type: NotificationPanelType.error,
        ),
      );
    }
  }

  Widget _build(BuildContext context) {
    if (_isExpanded == null) {
      _isExpanded = !widget.uiContext.qualifiedType.type.nullable &&
              widget.uiContext.value != null ||
          widget.uiContext.value != null;
    } else if (_isExpanded && widget.uiContext.value == null) {
      _isExpanded = false;
    }

    var label = widget.uiContext.getDecorationLabel();

    var margin = EdgeInsets.only(bottom: 5);

    // Return widget for null record in the read only mode.
    if (isRecordReadOnly &&
        DataTypeUtils.isValueNotSet(widget.uiContext.value)) {
      return TextViewWidget(
        label: label,
        text: null,
        compact: true,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (widget.uiContext.qualifiedType.type.nullable ||
                DataTypeUtils.isValueNotSet(widget.uiContext.value))
              IconButton(
                key: Key('record-expand'),
                icon: Icon(_isExpanded
                    ? Icons.check_box
                    : Icons.check_box_outline_blank),
                tooltip: 'Set nullable value',
                onPressed: isRecordEnabled && !isRecordReadOnly
                    ? () {
                        setState(() {
                          _toggleExpand();
                        });
                      }
                    : null,
              ),
            if (label != null)
              Text(
                label,
                style: getArgLabelTextStyle(context),
              ),
          ],
          //alignment: Alignment.centerLeft,
        ),
        if (_isExpanded)
          Container(
            height: 5,
          ),
        if (_isExpanded) ..._buildSubActionsWidget(context),
        if (_isExpanded)
          OptionalExpanded(
            child: widget.uiContext.qualifiedType.isRoot
                ? Container(
                    margin: margin,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildFieldsWidgets(context),
                    ),
                  )
                : Card(
                    margin: margin,
                    elevation: 0,
                    //shape: BeveledRectangleBorder(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildFieldsWidgets(context),
                    ),
                    color: Theme.of(widget.uiContext.context)
                        .scaffoldBackgroundColor,
                    shape: ContinuousRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: getBorderColor(widget.uiContext.context),
                      ),
                    ),
                  ),
          ),
      ],
    );
  }

  void _toggleExpand() {
    _isExpanded = !_isExpanded;

    if (_isExpanded) {
      if (widget.uiContext.value == null) {
        var newValue = <String, dynamic>{};
        var defaultValue = DataTypeUtils.unwrapAnnotatedValue(
            widget.uiContext.qualifiedType.type.defaultValue);

        if (defaultValue != null) {
          Validate.isTrue(defaultValue is Map<String, dynamic>,
              'A default value for a record should be a map');
          newValue = defaultValue;
        }

        widget.uiContext.value = newValue;
      }
    } else {
      widget.uiContext.value = null;
    }

    _onSave(widget.uiContext.qualifiedType, widget.uiContext.value);
  }

  List<Widget> _buildSubActionsWidget(BuildContext context) {
    var widgets = <Widget>[];

    // TODO Presenter.
    var service = ApplicationProvider.of(context).service;

    // Show context actions only for normal records (i.e. not for a logical record
    // that represents the action args).
    if (!widget.uiContext.qualifiedType.isRoot) {
      var subActionsWidget = SubActionsWidget.forRecord(
        widget.uiContext,
        service.spongeService,
        tooltip: 'Context actions',
      );

      if (subActionsWidget != null) {
        widgets.add(Align(
          child: Container(
            child: subActionsWidget,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).dividerColor,
            ),
            margin: EdgeInsets.only(bottom: 5, right: 5),
          ),
          alignment: Alignment.centerRight,
        ));
      }
    }

    return widgets;
  }

  List<Widget> _buildFieldsWidgets(BuildContext context) {
    var recordType = widget.uiContext.qualifiedType.type as RecordType;

    // TODO Presenter.
    var service = ApplicationProvider.of(context).service;
    _typeGuiProviders ??= {
      for (var field in recordType.fields)
        field.name: service.getTypeGuiProvider(field)
    };

    var widgets = <Widget>[];

    var groups = _createFieldGroups(recordType);
    groups.asMap().forEach((i, group) {
      widgets.add(_buildFieldGroupWidget(context, group));

      if (i < groups.length - 1) {
        widgets.add(Divider(height: 10));
      }
    });

    return widgets;
  }

  List<List<DataType>> _createFieldGroups(RecordType recordType) {
    var groups = <List<DataType>>[];
    String lastGroupName;
    int lastGroupIndex = -1;

    // TODO Util method - merge with annotated features.
    recordType.fields
        .where((fieldType) => fieldType.features[Features.VISIBLE] ?? true)
        .toList()
        .asMap()
        .forEach((i, fieldType) {
      String fieldGroup = fieldType.features[Features.GROUP];
      if (lastGroupName != null && lastGroupName == fieldGroup) {
        groups[lastGroupIndex].add(fieldType);
      } else {
        groups.add([fieldType]);
        lastGroupIndex++;
      }

      lastGroupName = fieldGroup;
    });

    return groups;
  }

  Widget _buildFieldGroupWidget(
      BuildContext context, List<DataType> fieldGroup) {
    Widget groupWidget;

    List<Widget> rawFieldWidgets = fieldGroup
        .map((fieldType) => _buildFieldWidget(
              context,
              widget.uiContext.qualifiedType,
              widget.uiContext.qualifiedType.createChild(fieldType),
              widget.uiContext.value as Map,
            ))
        .toList();

    if (rawFieldWidgets.length > 1) {
      groupWidget = Wrap(
        spacing: 10,
        runSpacing: 10,
        children: rawFieldWidgets,
      );
    } else if (rawFieldWidgets.length == 1) {
      groupWidget = rawFieldWidgets.first;
    }

    groupWidget = Padding(
      padding: widget.uiContext.rootRecordSingleLeadingField != null &&
              widget.uiContext.qualifiedType.isRoot
          ? const EdgeInsets.all(0)
          : const EdgeInsets.only(left: 10, right: 10, top: 0, bottom: 0),
      child: Align(
        child: groupWidget,
        alignment: Alignment.centerLeft,
      ),
    );

    return
        // Expanded only if any in a group field shoud have a scroll.
        fieldGroup.any(
                (fieldType) => DataTypeGuiUtils.hasListTypeScroll(fieldType))
            ? OptionalExpanded(child: groupWidget)
            : groupWidget;
  }

  void _onSave(QualifiedDataType qType, dynamic value) {
    widget.uiContext.callbacks.onSave(qType, value);
  }

  void _onUpdate(QualifiedDataType qType, dynamic value) {
    widget.uiContext.callbacks.onUpdate(qType, value);
  }

  TypeEditorContext _createEditorContext(
      QualifiedDataType qFieldType, Map record) {
    var qRecordType = widget.uiContext.qualifiedType;

    Validate.notNull(
        record, 'The record ${qRecordType.type.name} must not be null');
    var fieldValue = record[qFieldType.type.name];
    var onSave = (value) => setState(() {
          _onSave(qFieldType, value);
        });
    var onUpdate = (value) => setState(() {
          _onUpdate(qFieldType, value);
        });

    var shouldFieldBeEnabled =
        widget.uiContext.callbacks.shouldBeEnabled(qFieldType);

    return TypeEditorContext(
      widget.uiContext.name,
      context,
      widget.uiContext.callbacks,
      qFieldType,
      fieldValue,
      hintText: qFieldType.type.description,
      onSave: onSave,
      onUpdate: onUpdate,
      readOnly: isRecordReadOnly || !shouldFieldBeEnabled || !isRecordEnabled,
      enabled: isRecordEnabled && shouldFieldBeEnabled,
      loading: widget.uiContext.loading,
      rootRecordSingleLeadingField:
          widget.uiContext.rootRecordSingleLeadingField,
    );
  }

  Widget _buildFieldWidget(BuildContext context, QualifiedDataType recordType,
      QualifiedDataType qFieldType, Map record) {
    try {
      var editorContext = _createEditorContext(qFieldType, record);

      if (qFieldType.type.provided?.hasValueSet ?? false) {
        return AbsorbPointer(
          child: ProvidedValueSetEditorWidget(
            editorContext.getDecorationLabel(),
            qFieldType,
            qFieldType.type.provided.valueSet,
            editorContext.value,
            widget.uiContext.callbacks.onGetProvidedArg,
            editorContext.onSave,
          ),
          absorbing: qFieldType.type.provided.readOnly || !isRecordEnabled,
        );
      }

      var isFieldReadOnly = qFieldType.type.provided?.readOnly ?? false;

      // Switch to a viewer for a record field if necessary.
      if (isRecordReadOnly || isFieldReadOnly || !isRecordEnabled) {
        return Padding(
          padding: EdgeInsets.only(left: 0, right: 0, top: 5, bottom: 5),
          child: _typeGuiProviders[qFieldType.type.name]
              .createViewer(editorContext.cloneAsViewer()),
        );
      }

      return _typeGuiProviders[qFieldType.type.name]
          .createEditor(editorContext);
    } catch (e) {
      return NotificationPanelWidget(
        notification: e,
        type: NotificationPanelType.error,
      );
    }
  }
}

typedef GetProvidedArgCallback = ProvidedValue Function(
    QualifiedDataType qType);

// TODO Handle readOnly providedValueSet.
// TODO Handle value set in GuiProviders - typed.
class ProvidedValueSetEditorWidget extends StatefulWidget {
  ProvidedValueSetEditorWidget(
    this.label,
    this.qType,
    this.valueSetMeta,
    this.value,
    this.onGetProvidedArg,
    this.onSaved,
  );
  final String label;
  final QualifiedDataType qType;
  final ValueSetMeta valueSetMeta;
  final dynamic value;
  final GetProvidedArgCallback onGetProvidedArg;
  final ValueChanged onSaved;

  @override
  _ProvidedValueSetEditorWidgetState createState() =>
      _ProvidedValueSetEditorWidgetState();
}

class _ProvidedValueSetEditorWidgetState
    extends State<ProvidedValueSetEditorWidget> {
  TextEditingController _controller;

  /// Creates a new controller initially and every time an argument value has changed.
  TextEditingController getOrCreateController() {
    if (_controller == null || widget.value != _controller.text) {
      // TODO Dispose controller when creating a new one.
      _controller = TextEditingController(text: widget.value?.toString() ?? '')
        ..addListener(() {
          widget.onSaved(_controller.text);
        });
    }

    return _controller;
  }

  @override
  void dispose() {
    super.dispose();

    _controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.valueSetMeta.limited) {
      var items = _getLimitedMenuItems();
      var hasItems = items.isNotEmpty;

      var dropdown = DropdownButtonHideUnderline(
        child: DropdownButton(
          key: createDataTypeKey(widget.qType),
          value: hasItems ? widget.value : null,
          items: hasItems ? items : null,
          onChanged: (value) {
            setState(() {});
            widget.onSaved(value);
          },
          disabledHint: Container(),
          isExpanded: true,
        ),
      );

      return widget.label != null
          ? Row(
              children: <Widget>[
                Text(
                  widget.label,
                  style: getArgLabelTextStyle(context),
                ),
                Container(
                  padding: EdgeInsets.all(16.0),
                ),
                Expanded(
                  child: dropdown,
                ),
              ],
            )
          : dropdown;
    } else {
      // TODO Only String non-limited values are supported.

      var items = _getNotLimitedMenuItems();
      return Row(
        children: <Widget>[
          Flexible(
            child: TextField(
              key: createDataTypeKey(widget.qType),
              decoration: widget.label != null
                  ? InputDecoration(
                      border: InputBorder.none, labelText: widget.label)
                  : null,
              controller: getOrCreateController(),
            ),
          ),
          Visibility(
            child: PopupMenuButton(
              key: Key('popup-${createDataTypeKeyValue(widget.qType)}'),
              itemBuilder: (BuildContext context) => items,
              onSelected: (value) {
                _controller.text = value?.toString();
              },
            ),
            visible: !(items?.isEmpty ?? true),
          ),
        ],
      );
    }
  }

  List<AnnotatedValue> _getValueSetValues() {
    ProvidedValue argValue = widget.onGetProvidedArg(widget.qType);
    return argValue?.annotatedValueSet
            ?.where((annotatedValue) => annotatedValue != null)
            ?.toList() ??
        [];
  }

  List<DropdownMenuItem<dynamic>> _getLimitedMenuItems() {
    List<AnnotatedValue> valueSetValues = _getValueSetValues();

    // If the type is nullable and has value set that contains no null values, insert a first element that has a null value.
    if (widget.qType.type.nullable &&
        valueSetValues.every((valueSetValue) => valueSetValue?.value != null)) {
      valueSetValues = []
        ..add(AnnotatedValue(null))
        ..addAll(valueSetValues);
    }

    return valueSetValues
        .map((annotatedValue) => DropdownMenuItem(
              value: annotatedValue.value,
              child: Text(annotatedValue.valueLabel ??
                  annotatedValue.value?.toString() ??
                  ''),
            ))
        .toList();
  }

  List<PopupMenuItem> _getNotLimitedMenuItems() {
    return _getValueSetValues()
        .map((annotatedValue) => PopupMenuItem(
              value: annotatedValue.value,
              child: Text(annotatedValue.valueLabel ??
                  annotatedValue.value?.toString() ??
                  ''),
            ))
        .toList();
  }
}

class ColorEditWidget extends StatefulWidget {
  ColorEditWidget({
    Key key,
    @required this.name,
    @required this.initialColor,
    @required this.onColorChanged,
    @required this.defaultColor,
    this.enabled = true,
  }) : super(key: key);

  final String name;
  final Color initialColor;
  final Color defaultColor;
  final ValueChanged<Color> onColorChanged;
  final bool enabled;

  @override
  _ColorEditWidgetState createState() => _ColorEditWidgetState();
}

class _ColorEditWidgetState extends State<ColorEditWidget> {
  Color _currentPickerColor;

  @override
  Widget build(BuildContext context) {
    var suggestedColor = widget.initialColor ?? widget.defaultColor;
    return FlatButton(
      child: Text(
        '${widget.name ?? 'Color'}${widget.initialColor != null ? " (" + color2string(widget.initialColor) + ")" : ""}',
        style: TextStyle(color: getContrastColor(suggestedColor)),
      ),
      color: suggestedColor,
      onPressed: widget.enabled
          ? () => showColorPicker(context, suggestedColor)
          : null,
    );
  }

  Future<void> showColorPicker(
      BuildContext context, Color suggestedColor) async {
    Color choosenColor = await showDialog<Color>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: suggestedColor,
            onColorChanged: (color) => _currentPickerColor = color,
            showLabel: true,
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
          ),
        ),
        actions: <Widget>[
          FlatButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop(_currentPickerColor);
            },
          ),
          FlatButton(
            child: Text('CANCEL'),
            onPressed: () {
              Navigator.of(context).pop(null);
            },
          ),
        ],
      ),
    );

    if (choosenColor != null) {
      widget.onColorChanged(choosenColor);
    }
  }
}

class DateTimeEditWidget extends StatefulWidget {
  DateTimeEditWidget({
    Key key,
    @required this.name,
    @required this.initialValue,
    @required this.onValueChanged,
    this.enabled = true,
    this.firstDate,
    this.lastDate,
    this.yearsRange = 200,
  }) : super(key: key);

  final String name;
  final DateTime initialValue;
  final ValueChanged<DateTime> onValueChanged;
  final bool enabled;
  final DateTime firstDate;
  final DateTime lastDate;
  final int yearsRange;

  @override
  _DateTimeEditWidgetState createState() => _DateTimeEditWidgetState();
}

// TODO DateTime editor support for different dateTimeKind.
class _DateTimeEditWidgetState extends State<DateTimeEditWidget> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.name != null) Text(widget.name),
        FlatButton(
          child: Text(widget.initialValue != null
              ? DateFormat('yyyy-MM-dd').format(widget.initialValue)
              : 'DATE'),
          onPressed: () =>
              _showDatePicker().catchError((e) => handleError(context, e)),
        ),
        FlatButton(
          child: Text(widget.initialValue != null
              ? DateFormat('HH:mm').format(widget.initialValue)
              : 'TIME'),
          onPressed: () =>
              _showTimePicker().catchError((e) => handleError(context, e)),
        ),
      ],
    );
  }

  Future<void> _showDatePicker() async {
    DateTime now = DateTime.now();
    DateTime initialDate = widget.initialValue ?? now;

    DateTime firstDate =
        widget.firstDate ?? Jiffy(now).subtract(years: widget.yearsRange);
    // Apply a tolerance.
    if (Jiffy(firstDate).add(years: 1).isAfter(initialDate)) {
      firstDate = Jiffy(initialDate).subtract(years: widget.yearsRange);
    }

    DateTime lastDate =
        widget.lastDate ?? Jiffy(now).add(years: widget.yearsRange);
    // Apply a tolerance.
    if (Jiffy(lastDate).subtract(years: 1).isBefore(initialDate)) {
      lastDate = Jiffy(initialDate).add(years: widget.yearsRange);
    }

    DateTime picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      widget.onValueChanged(picked);
    }
  }

  Future<void> _showTimePicker() async {
    TimeOfDay initialTime = widget.initialValue != null
        ? TimeOfDay.fromDateTime(widget.initialValue)
        : TimeOfDay.now();
    TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      var newValue = widget.initialValue ?? DateTime.now();
      newValue = DateTime(
          newValue.year,
          newValue.month,
          newValue.day,
          picked.hour,
          picked.minute,
          newValue.second,
          newValue.millisecond,
          newValue.microsecond);

      widget.onValueChanged(newValue);
    }
  }
}

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

class SliderWidget extends StatefulWidget {
  SliderWidget({
    Key key,
    @required this.name,
    @required this.initialValue,
    @required this.minValue,
    @required this.maxValue,
    @required this.onValueChanged,
    this.responsive = false,
    this.enabled = true,
  }) : super(key: key);

  final String name;
  final int initialValue;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onValueChanged;
  final bool responsive;
  final bool enabled;

  @override
  _SliderWidgetState createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget> {
  int _value;
  bool _changingByUi = false;

  @override
  Widget build(BuildContext context) {
    if (_value == null || !_changingByUi || widget.responsive) {
      _value = widget.initialValue;
    }

    return Slider(
      activeColor: Theme.of(context).accentColor,
      label: widget.name,
      min: widget.minValue.roundToDouble(),
      max: widget.maxValue.roundToDouble(),
      value: _value?.roundToDouble() ?? widget.minValue.roundToDouble(),
      onChanged: widget.enabled
          ? (value) async {
              if (!widget.responsive) {
                _changingByUi = true;
                setState(() {
                  _value = value.toInt();
                });
              } else {
                widget.onValueChanged(value?.toInt());
              }
            }
          : null,
      onChangeEnd: (value) async {
        if (!widget.responsive) {
          _changingByUi = false;
          widget.onValueChanged(value?.toInt());
        }
      },
    );
  }
}

class TextEditWidget extends StatefulWidget {
  TextEditWidget({
    Key key,
    @required this.editorContext,
    @required this.inputType,
    this.validator,
    this.maxLines,
    @required this.onGetValueFromString,
  }) : super(key: key);

  final TypeEditorContext editorContext;
  final TextInputType inputType;
  final TypeEditorValidatorCallback validator;
  final int maxLines;
  final dynamic Function(String) onGetValueFromString;

  @override
  _TextEditWidgetState createState() => _TextEditWidgetState();
}

class _TextEditWidgetState extends State<TextEditWidget> {
  TextEditingController _controller;

  String get _sourceValue => widget.editorContext.value?.toString() ?? '';

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: _sourceValue)
      ..addListener(() {
        widget.editorContext
            .onUpdate(widget.onGetValueFromString(_controller.text));
      });
  }

  @override
  void dispose() {
    super.dispose();

    _controller?.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controller.value =
        TextEditingController.fromValue(TextEditingValue(text: _sourceValue))
            .value;
  }

  @override
  Widget build(BuildContext context) {
    return _createTextEditWidget(
      widget.editorContext,
      inputType: widget.inputType,
    );
  }

  Widget _createTextEditWidget<T extends DataType>(
    TypeEditorContext editorContext, {
    @required TextInputType inputType,
    TypeEditorValidatorCallback validator,
    int maxLines,
  }) {
    var decoration = InputDecoration(
        border: InputBorder.none,
        labelText: editorContext.getDecorationLabel(),
        hintText: editorContext.hintText,
        suffixIcon: editorContext.enabled && !editorContext.readOnly
            ? InkResponse(
                key: Key('text-clear'),
                child: Icon(
                  MdiIcons.close,
                  //Icons.cancel,
                  color: Colors.grey,
                  size: getArgLabelTextStyle(editorContext.context).fontSize *
                      1.5,
                ),
                onTap: () => WidgetsBinding.instance
                    .addPostFrameCallback((_) => _controller.clear()))
            : null);
    bool obscure = Features.getOptional(
        editorContext.features, Features.STRING_OBSCURE, () => false);

    return TextFormField(
      key: createDataTypeKey(editorContext.qualifiedType),
      controller: _controller,
      keyboardType: inputType,
      decoration: decoration,
      // Both callbacks onFieldSubmitted and onSaved are necessary.
      onFieldSubmitted: (String value) {
        editorContext.onSave(widget.onGetValueFromString(value));
      },
      onSaved: (String value) {
        editorContext.onSave(widget.onGetValueFromString(value));
      },
      validator: (value) {
        if (!editorContext.qualifiedType.type.nullable && value.isEmpty) {
          return '${editorContext.qualifiedType.type.label ?? "Value"} is required';
        }

        return validator != null
            ? validator(widget.onGetValueFromString(value))
            : null;
      },
      maxLines: obscure ? 1 : maxLines,
      enabled: editorContext.enabled && !editorContext.readOnly,
      obscureText: obscure,
    );
  }
}

class MapTypeWidget extends StatefulWidget {
  MapTypeWidget({Key key, this.uiContext}) : super(key: key);

  final UiContext uiContext;

  @override
  _MapTypeWidgetState createState() => _MapTypeWidgetState();
}

class _MapTypeWidgetState extends State<MapTypeWidget> {
  MapType get type => widget.uiContext.qualifiedType.type;

  @override
  Widget build(BuildContext context) {
    var label = widget.uiContext.getDecorationLabel();
    var valueMap = widget.uiContext.value as Map;

    var keyLabel = type.keyType.label;
    var valueLabel = type.valueType.label;

    var margin = EdgeInsets.all(5);

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
                  child: Text(keyLabel),
                ),
                Container(
                  margin: margin,
                  child: Text(valueLabel),
                ),
              ]),
            ...(valueMap ?? {})
                .keys
                .toList()
                .asMap()
                .entries
                .map<TableRow>((entry) {
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
