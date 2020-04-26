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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/sponge_flutter_api.dart';
import 'package:sponge_flutter_api/src/flutter/ui/context/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/drawing_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/gui_utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type_support/date_time_edit_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type/list_type_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type/map_type_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type/multi_choice_list_edit_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type/record_type_widget.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/type_support/slider.dart';

abstract class BaseUnitTypeGuiProvider<T extends DataType>
    extends UnitTypeGuiProvider<T> {
  BaseUnitTypeGuiProvider(T type) : super(type);

  @override
  Widget createEditor(TypeEditorContext editorContext) => null;

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) => null;

  @override
  Widget createViewer(TypeViewerContext viewerContext) => null;

  @override
  Widget createExtendedViewer(TypeViewerContext viewerContext) => null;
}

class AnyTypeGuiProvider extends BaseUnitTypeGuiProvider<AnyType> {
  AnyTypeGuiProvider(DataType type) : super(type);
}

class BinaryTypeGuiProvider extends BaseUnitTypeGuiProvider<BinaryType> {
  BinaryTypeGuiProvider(DataType type) : super(type);

  Uint8List _compactViewerThumbnailCache;

  String getMimeType(UiContext uiContext) => DataTypeUtils.getFeatureOrProperty(
      type, uiContext.value, BinaryType.FEATURE_MIME_TYPE, () => type.mimeType);

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    switch (getMimeType(editorContext)) {
      case 'image/png':
        switch (Features.getCharacteristic(editorContext.features)) {
          case Features.TYPE_CHARACTERISTIC_DRAWING:
            Widget thumbnail = editorContext.value != null
                ? FutureBuilder(
                    future: _createDrawingThumbnail(
                        editorContext.value as DrawingBinaryValue),
                    builder: (BuildContext context,
                            AsyncSnapshot<Uint8List> snapshot) =>
                        snapshot.hasData
                            ? Image.memory(snapshot.data)
                            : snapshot.hasError
                                ? Text('Error: ${snapshot.error}')
                                : CircularProgressIndicator(),
                  )
                : null;
            return Container(
              child: FlatButton(
                color: Theme.of(editorContext.context).primaryColor,
                textColor: Colors.white,
                onPressed: editorContext.enabled
                    ? () async {
                        DrawingBinaryValue oldValue =
                            editorContext.value ?? DrawingBinaryValue(type);
                        DrawingBinaryValue binaryValue = await Navigator.push(
                          editorContext.context,
                          MaterialPageRoute<DrawingBinaryValue>(
                            builder: (context) => DrawingPage(
                              name: editorContext.typeLabel,
                              drawingBinary: oldValue,
                            ),
                          ),
                        );
                        editorContext.onSave(binaryValue);
                      }
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Text(editorContext.getDecorationLabel(
                        customLabel:
                            'DRAW ${editorContext.typeLabel?.toUpperCase()}')),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(child: thumbnail ?? Container()),
                    ),
                  ],
                ),
              ),
            );
            break;
        }
    }

    return TypeGuiProviderUtils.createUnsupportedTypeEditor(type,
        labelText: editorContext.safeTypeLabel,
        hintText: editorContext.hintText,
        message:
            'Unsupported binary type mime=${getMimeType(editorContext)}, features=${editorContext.features}');
  }

  Future<Uint8List> _createDrawingThumbnail(DrawingBinaryValue value) async =>
      await DrawingUtils.convertDrawingToPng(value, width: 100);

  Widget _createCompactViewerDataWidget(TypeViewerContext viewerContext) {
    var mimeType = getMimeType(viewerContext) ?? '';

    if (mimeType.startsWith('image/')) {
      _compactViewerThumbnailCache ??=
          createThumbnail(viewerContext.value, 100);

      return Image.memory(_compactViewerThumbnailCache);
    }

    if (viewerContext.value == null) {
      return Text('None',
          style: DefaultTextStyle.of(viewerContext.context)
              .style
              .apply(fontSizeFactor: 1.5));
    }

    return getIcon(
      viewerContext.context,
      viewerContext.service,
      Features.getIcon(viewerContext.features),
      orIconData: () => Icons.insert_drive_file,
      forcedSize: 50,
    );
  }

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (viewerContext.typeLabel != null) Text(viewerContext.typeLabel),
        if (viewerContext.typeLabel != null)
          Container(
            margin: EdgeInsets.all(2.0),
          ),
        Center(child: _createCompactViewerDataWidget(viewerContext)),
      ],
    );
  }

  @override
  Widget createViewer(TypeViewerContext viewerContext) {
    // TODO Binary viewer for images should have an option to be inline.
    return InkResponse(
      onTap: () => navigateToExtendedViewer(
        typeProviderRegistry.getProvider(type),
        viewerContext.clone(),
      ),
      child: createCompactViewer(viewerContext),
    );
  }
}

class BooleanTypeGuiProvider extends BaseUnitTypeGuiProvider<BooleanType> {
  BooleanTypeGuiProvider(DataType type) : super(type);

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    String widgetType = Features.getOptional(
        editorContext.features, Features.WIDGET, () => null);
    var iconInfo = Features.getIcon(editorContext.features);

    var onChanged = (editorContext.readOnly || !editorContext.enabled)
        ? null
        : (bool value) => editorContext.onSave(value);

    var label = editorContext.getDecorationLabel();

    var wrap = (Widget widget) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (label != null)
              Text(
                label,
                style: getArgLabelTextStyle(editorContext.context),
              ),
            widget,
          ],
        );

    if (widgetType == Features.WIDGET_SWITCH &&
        !editorContext.qualifiedType.type.nullable) {
      return wrap(Switch(
        key: createDataTypeKey(editorContext.qualifiedType),
        value: editorContext.value ?? (type.nullable ? null : false),
        onChanged: onChanged,
      ));
    } else if (iconInfo?.name != null &&
        !editorContext.qualifiedType.type.nullable) {
      return IconButton(
        key: createDataTypeKey(editorContext.qualifiedType),
        icon: getIcon(editorContext.context, editorContext.service, iconInfo),
        onPressed: onChanged != null
            ? () => onChanged(!(editorContext.value as bool))
            : null,
      );
    } else {
      return wrap(Checkbox(
        key: createDataTypeKey(editorContext.qualifiedType),
        value: editorContext.value ?? (type.nullable ? null : false),
        onChanged: onChanged,
        tristate: type.nullable,
      ));
    }
  }

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedCompactViewer(viewerContext);

  @override
  Widget createViewer(TypeViewerContext viewerContext) {
    var boolValue = viewerContext.value as bool;

    var label = viewerContext.getDecorationLabel();

    return boolValue != null
        ? CheckboxListTile(
            title: label != null
                ? Text(
                    label,
                    style: getArgLabelTextStyle(viewerContext.context),
                  )
                : null,
            value: boolValue,
            onChanged: null,
            dense: true,
          )
        : null;
  }
}

class DateTimeTypeGuiProvider extends BaseUnitTypeGuiProvider<DateTimeType> {
  DateTimeTypeGuiProvider(DataType type) : super(type);

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    if (editorContext.readOnly) {
      return createCompactViewer(editorContext.cloneAsViewer());
    } else {
      return DateTimeEditWidget(
        key: createDataTypeKey(editorContext.qualifiedType),
        name: editorContext.getDecorationLabel(),
        initialValue: editorContext.value,
        onValueChanged: editorContext.onSave,
        enabled: editorContext.enabled && !editorContext.readOnly,
        firstDate: type.minValue,
        lastDate: type.maxValue,
      );
    }
  }

  String _valueToString(UiContext uiContext) {
    String format = TypeGuiProviderUtils.getFormat(uiContext);
    if (uiContext.value != null && format != null) {
      return DateFormat(format).format(uiContext.value);
    }

    return uiContext.value?.toString();
  }

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedCompactViewer(
          viewerContext.clone()..value = _valueToString(viewerContext));

  @override
  Widget createViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedViewer(
          viewerContext.clone()..value = _valueToString(viewerContext));
}

class DynamicTypeGuiProvider extends BaseUnitTypeGuiProvider<DynamicType> {
  DynamicTypeGuiProvider(DataType type) : super(type);

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    var dynamicValue = editorContext.value as DynamicValue;

    if (dynamicValue == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: TypeGuiProviderUtils.createTextBasedCompactViewer(
            editorContext.cloneAsViewer()),
      );
    }

    Validate.notNull(dynamicValue.type, 'A dynamic type is not set');

    QualifiedDataType qualifiedType =
        _createTargetQualifiedDataType(editorContext);

    if (editorContext.readOnly) {
      return createViewer(editorContext.cloneAsViewer());
    } else {
      return typeProviderRegistry
          .getProvider(dynamicValue.type)
          .createEditor(editorContext.clone()
            ..value = dynamicValue.value
            ..qualifiedType = qualifiedType);
    }
  }

  QualifiedDataType _createTargetQualifiedDataType(UiContext uiContext) =>
      QualifiedDataType(
        (uiContext.value as DynamicValue)?.type,
        path: uiContext.qualifiedType.path,
        isRoot: uiContext.qualifiedType.isRoot,
      );

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) {
    if (viewerContext.value == null) {
      return TypeGuiProviderUtils.createTextBasedCompactViewer(viewerContext);
    }

    var dynamicValue = viewerContext.value as DynamicValue;
    Validate.notNull(dynamicValue.type, 'A dynamic type is not set');

    return typeProviderRegistry
        .getProvider(dynamicValue.type)
        .createCompactViewer(viewerContext.clone()
          ..value = dynamicValue.value
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }

  @override
  Widget createViewer(TypeViewerContext viewerContext) {
    if (viewerContext.value == null) {
      return TypeGuiProviderUtils.createTextBasedViewer(viewerContext);
    }

    var dynamicValue = viewerContext.value as DynamicValue;
    Validate.notNull(dynamicValue.type, 'A dynamic type is not set');

    return typeProviderRegistry
        .getProvider(dynamicValue.type)
        .createViewer(viewerContext.clone()
          ..value = dynamicValue.value
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }

  @override
  Widget createExtendedViewer(TypeViewerContext viewerContext) {
    if (viewerContext.value == null) {
      return null;
    }

    var dynamicValue = viewerContext.value as DynamicValue;
    Validate.notNull(dynamicValue.type, 'A dynamic type is not set');

    return typeProviderRegistry
        .getProvider(dynamicValue.type)
        .createExtendedViewer(viewerContext.clone()
          ..value = dynamicValue.value
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }
}

class IntegerTypeGuiProvider extends BaseUnitTypeGuiProvider<IntegerType> {
  IntegerTypeGuiProvider(DataType type) : super(type);

  int _getValueFromString(String s) {
    var normalized = CommonUtils.normalizeString(s);

    return normalized != null ? int.parse(normalized) : null;
  }

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    int minValue = DataTypeUtils.getFeatureOrProperty(type, editorContext.value,
        IntegerType.FEATURE_MIN_VALUE, () => type.minValue);
    int maxValue = DataTypeUtils.getFeatureOrProperty(type, editorContext.value,
        IntegerType.FEATURE_MAX_VALUE, () => type.maxValue);
    bool exclusiveMin = DataTypeUtils.getFeatureOrProperty(
        type,
        editorContext.value,
        IntegerType.FEATURE_EXCLUSIVE_MIN,
        () => type.exclusiveMin);
    bool exclusiveMax = DataTypeUtils.getFeatureOrProperty(
        type,
        editorContext.value,
        IntegerType.FEATURE_EXCLUSIVE_MAX,
        () => type.exclusiveMax);

    String widgetFeature = DataTypeUtils.getFeatureOrProperty(
        type, editorContext.value, Features.WIDGET, () => null);

    if (widgetFeature == Features.WIDGET_SLIDER &&
        minValue != null &&
        maxValue != null) {
      bool responsive = DataTypeUtils.getFeatureOrProperty(
          type, editorContext.value, Features.RESPONSIVE, () => false);

      var label = editorContext.getDecorationLabel();

      return Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: label != null
                ? Text(
                    label,
                    style: getArgLabelTextStyle(editorContext.context),
                  )
                : null,
            subtitle: SliderWidget(
              key: createDataTypeKey(editorContext.qualifiedType),
              name: label,
              initialValue: editorContext.value,
              minValue: minValue,
              maxValue: maxValue,
              onValueChanged: editorContext.onSave,
              responsive: responsive,
              enabled: editorContext.enabled,
            ),
          ),
        ],
      );
    }

    return TextEditWidget(
      editorContext: editorContext,
      inputType: TextInputType.numberWithOptions(decimal: false),
      validator: (value) {
        int intValue = value as int;

        String message = TypeGuiProviderUtils.validateNumberRange(
            intValue, minValue, exclusiveMin, maxValue, exclusiveMax);
        if (message != null) {
          return message;
        }

        return editorContext.validator?.call(value);
      },
      onGetValueFromString: (String value) => _getValueFromString(value),
      labelSuffix: TypeGuiProviderUtils.getNumberRangeLabel(minValue, maxValue),
    );
  }

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedCompactViewer(viewerContext);

  @override
  Widget createViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedViewer(viewerContext);
}

class ListTypeGuiProvider extends BaseUnitTypeGuiProvider<ListType> {
  ListTypeGuiProvider(DataType type) : super(type);

  TypeGuiProvider getElementTypeProvider() {
    return typeProviderRegistry.getProvider(type.elementType);
  }

  bool _useScrollableIndexedList(UiContext uiContext) =>
      uiContext.service.settings.useScrollableIndexedList;

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    var hasElementValueSet = type.provided?.elementValueSet ?? false;
    if (hasElementValueSet) {
      return type.unique
          ? MultiChoiceListEditWidget(
              key: createDataTypeKey(editorContext.qualifiedType),
              viewModel: MultiChoiceListEditViewModel(
                qType: editorContext.qualifiedType,
                labelText: editorContext.getDecorationLabel(),
                value: editorContext.value as List,
                onGetProvidedArg: editorContext.callbacks.onGetProvidedArg,
                onSave: editorContext.onSave,
                enabled: editorContext.enabled,
              ),
            )
          : null;
    } else {
      // TODO The type.unique is not handled in GUI.
      return ListTypeWidget(
        key: createDataTypeKey(editorContext.qualifiedType),
        uiContext: editorContext,
        guiProvider: this,
        useScrollableIndexedList: _useScrollableIndexedList(editorContext),
      );
    }
  }

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) {
    return ListTypeWidget(
      key: createDataTypeKey(viewerContext.qualifiedType),
      uiContext: viewerContext,
      guiProvider: this,
      useScrollableIndexedList: _useScrollableIndexedList(viewerContext),
    );
  }

  @override
  Widget createViewer(TypeViewerContext viewerContext) {
    return ListTypeWidget(
      key: createDataTypeKey(viewerContext.qualifiedType),
      uiContext: viewerContext,
      guiProvider: this,
      useScrollableIndexedList: _useScrollableIndexedList(viewerContext),
    );
  }
}

class MapTypeGuiProvider extends BaseUnitTypeGuiProvider<MapType> {
  MapTypeGuiProvider(DataType type) : super(type);

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) =>
      MapTypeWidget(uiContext: viewerContext);

  @override
  Widget createViewer(TypeViewerContext viewerContext) =>
      MapTypeWidget(uiContext: viewerContext);
}

class NumberTypeGuiProvider extends BaseUnitTypeGuiProvider<NumberType> {
  NumberTypeGuiProvider(DataType type) : super(type);

  num _getValueFromString(String s) {
    var normalized = CommonUtils.normalizeString(s);

    return normalized != null ? num.parse(normalized) : null;
  }

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    num minValue = DataTypeUtils.getFeatureOrProperty(type, editorContext.value,
        NumberType.FEATURE_MIN_VALUE, () => type.minValue);
    num maxValue = DataTypeUtils.getFeatureOrProperty(type, editorContext.value,
        NumberType.FEATURE_MAX_VALUE, () => type.maxValue);
    bool exclusiveMin = DataTypeUtils.getFeatureOrProperty(
        type,
        editorContext.value,
        NumberType.FEATURE_EXCLUSIVE_MIN,
        () => type.exclusiveMin);
    bool exclusiveMax = DataTypeUtils.getFeatureOrProperty(
        type,
        editorContext.value,
        NumberType.FEATURE_EXCLUSIVE_MAX,
        () => type.exclusiveMax);

    return TextEditWidget(
      editorContext: editorContext,
      inputType: TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        num numValue = value as num;

        String message = TypeGuiProviderUtils.validateNumberRange(
            numValue, minValue, exclusiveMin, maxValue, exclusiveMax);
        if (message != null) {
          return message;
        }

        return editorContext.validator?.call(value);
      },
      onGetValueFromString: (String value) => _getValueFromString(value),
      labelSuffix: TypeGuiProviderUtils.getNumberRangeLabel(minValue, maxValue),
    );
  }

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedCompactViewer(viewerContext);

  @override
  Widget createViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedViewer(viewerContext);
}

class ObjectTypeGuiProvider extends BaseUnitTypeGuiProvider<ObjectType> {
  ObjectTypeGuiProvider(DataType type) : super(type);

  ObjectType _getObjectType(UiContext uiContext) =>
      uiContext.qualifiedType.type as ObjectType;

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    var objectType = _getObjectType(editorContext);

    if (objectType.companionType == null) {
      return null;
    }

    QualifiedDataType qualifiedType =
        _createTargetQualifiedDataType(editorContext);

    if (editorContext.readOnly) {
      return createViewer(editorContext.cloneAsViewer());
    } else {
      return typeProviderRegistry
          .getProvider(objectType.companionType)
          .createEditor(editorContext.clone()..qualifiedType = qualifiedType);
    }
  }

  QualifiedDataType _createTargetQualifiedDataType(UiContext uiContext) =>
      QualifiedDataType(
        (uiContext.qualifiedType.type as ObjectType).companionType,
        path: uiContext.qualifiedType.path,
        isRoot: uiContext.qualifiedType.isRoot,
      );

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) {
    var objectType = _getObjectType(viewerContext);

    if (objectType.companionType == null) {
      return null;
    }

    return typeProviderRegistry
        .getProvider(objectType.companionType)
        .createCompactViewer(viewerContext.clone()
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }

  @override
  Widget createViewer(TypeViewerContext viewerContext) {
    var objectType = _getObjectType(viewerContext);

    if (objectType.companionType == null) {
      return null;
    }

    return typeProviderRegistry
        .getProvider(objectType.companionType)
        .createViewer(viewerContext.clone()
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }

  @override
  Widget createExtendedViewer(TypeViewerContext viewerContext) {
    if (viewerContext.value == null) {
      return null;
    }

    var objectType = _getObjectType(viewerContext);

    if (objectType.companionType == null) {
      return null;
    }

    return typeProviderRegistry
        .getProvider(objectType.companionType)
        .createExtendedViewer(viewerContext.clone()
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }
}

class RecordTypeGuiProvider extends BaseUnitTypeGuiProvider<RecordType> {
  RecordTypeGuiProvider(DataType type) : super(type);

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    return RecordTypeWidget(
      key: createDataTypeKey(editorContext.qualifiedType),
      uiContext: editorContext,
    );
  }

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) {
    // Show a normal viewer.
    return createViewer(viewerContext);
  }

  @override
  Widget createViewer(TypeViewerContext viewerContext) {
    return RecordTypeWidget(
      key: createDataTypeKey(viewerContext.qualifiedType),
      uiContext: viewerContext,
    );
  }
}

class StreamTypeGuiProvider extends BaseUnitTypeGuiProvider<StreamType> {
  StreamTypeGuiProvider(DataType type) : super(type);
}

class StringTypeGuiProvider extends BaseUnitTypeGuiProvider<StringType> {
  StringTypeGuiProvider(DataType type) : super(type);

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    int minLength = DataTypeUtils.getFeatureOrProperty(
        type,
        editorContext.value,
        StringType.FEATURE_MIN_LENGTH,
        () => type.minLength);
    int maxLength = DataTypeUtils.getFeatureOrProperty(
        type,
        editorContext.value,
        StringType.FEATURE_MAX_LENGTH,
        () => type.maxLength);

    switch (Features.getCharacteristic(editorContext.features)) {
      case Features.TYPE_CHARACTERISTIC_COLOR:
        return Container(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ColorEditWidget(
                  key: createDataTypeKey(editorContext.qualifiedType),
                  name:
                      'PICK ${editorContext.typeLabel?.toUpperCase() ?? "COLOR"}',
                  initialColor: string2color(editorContext.value),
                  defaultColor: Colors.black,
                  onColorChanged: (color) =>
                      editorContext.onSave(color2string(color)),
                  enabled: editorContext.enabled && !editorContext.readOnly,
                ),
              ),
            ],
          ),
        );
        break;
      case Features.TYPE_CHARACTERISTIC_NETWORK_IMAGE:
        if (editorContext.readOnly) {
          return _createImageCharacteristicViewer(editorContext);
        }
        break;
      default:
        break;
    }

    // A default widget.
    bool multiline = Features.getOptional(
        editorContext.features, Features.STRING_MULTILINE, () => false);
    int maxLines = Features.getOptional(editorContext.features,
        Features.STRING_MAX_LINES, () => multiline ? null : 1);
    var inputType = (multiline || maxLines > 1)
        ? TextInputType.multiline
        : TextInputType.text;

    switch (TypeGuiProviderUtils.getFormat(editorContext)) {
      case Formats.STRING_FORMAT_PHONE:
        inputType = TextInputType.phone;
        break;
      case Formats.STRING_FORMAT_EMAIL:
        inputType = TextInputType.emailAddress;
        break;
      case Formats.STRING_FORMAT_URL:
        inputType = TextInputType.url;
        break;
    }

    return TextEditWidget(
      editorContext: editorContext,
      inputType: inputType,
      validator: (value) {
        if (minLength != null && value.length < minLength) {
          return 'The text is shorter than $minLength';
        }

        if (maxLength != null && value.length > maxLength) {
          return 'The text is longer than $maxLength';
        }

        return editorContext.validator?.call(value);
      },
      maxLines: maxLines,
      onGetValueFromString: (String value) =>
          CommonUtils.normalizeString(value),
    );
  }

  Widget _createImageCharacteristicViewer(UiContext uiContext) {
    if (uiContext.value != null) {
      var image = Provider.of<SpongeGuiFactory>(uiContext.context)
          .createNetworkImage(uiContext.value);

      if (image != null) {
        return Container(
          child: image,
          padding: EdgeInsets.symmetric(vertical: 5),
        );
      }
    }

    return null;
  }

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) {
    switch (Features.getCharacteristic(viewerContext.features)) {
      // TODO case Features.TYPE_CHARACTERISTIC_COLOR:
      case Features.TYPE_CHARACTERISTIC_NETWORK_IMAGE:
        return _createImageCharacteristicViewer(viewerContext);
        break;
      default:
        break;
    }

    return TypeGuiProviderUtils.createTextBasedCompactViewer(viewerContext);
  }

  @override
  Widget createViewer(TypeViewerContext viewerContext) {
    switch (Features.getCharacteristic(viewerContext.features)) {
      // TODO case Features.TYPE_CHARACTERISTIC_COLOR:
      case Features.TYPE_CHARACTERISTIC_NETWORK_IMAGE:
        return _createImageCharacteristicViewer(viewerContext);
        break;
      default:
        break;
    }

    return TypeGuiProviderUtils.createTextBasedViewer(viewerContext);
  }

  @override
  Widget createExtendedViewer(TypeViewerContext viewerContext) {
    return TypeGuiProviderUtils.createTextBasedExtendedViewer(viewerContext);
  }
}

class TypeTypeGuiProvider extends BaseUnitTypeGuiProvider<TypeType> {
  TypeTypeGuiProvider(DataType type) : super(type);
}

class VoidTypeGuiProvider extends BaseUnitTypeGuiProvider<VoidType> {
  VoidTypeGuiProvider(DataType type) : super(type);

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    var iconInfo = Features.getIcon(editorContext.features);

    var onTap = editorContext.enabled &&
            !editorContext.readOnly &&
            (editorContext.qualifiedType.type.provided?.submittable != null)
        ? () => editorContext.onSave(null)
        : null;

    if (iconInfo?.name != null) {
      return IconButton(
        key: createDataTypeKey(editorContext.qualifiedType),
        icon: getIcon(editorContext.context, editorContext.service, iconInfo),
        onPressed: onTap,
      );
    }
    return InkResponse(
      child: Chip(
        label: Text(editorContext.typeLabel ?? ''),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedCompactViewer(
          viewerContext.clone()..value = 'Success');
}
