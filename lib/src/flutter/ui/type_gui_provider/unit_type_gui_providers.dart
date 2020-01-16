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

//import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
//import 'package:downloads_path_provider/downloads_path_provider.dart';
//import 'package:simple_permissions/simple_permissions.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/sponge_flutter_api.dart';

abstract class BaseUnitTypeGuiProvider<T extends DataType>
    extends UnitTypeGuiProvider<T> {
  BaseUnitTypeGuiProvider(T type) : super(type);

  static final Logger _logger = Logger('BaseUnitTypeGuiProvider');

  @override
  Widget createEditor(TypeEditorContext editorContext) {
    setupContext(editorContext);

    try {
      if (TypeGuiProviderUtils.isWaitingForValue(editorContext)) {
        return TypeGuiProviderUtils.createWaitingViewer(editorContext);
      }

      return doCreateEditor(editorContext) ??
          TypeGuiProviderUtils.createUnsupportedTypeEditor(this,
              labelText: editorContext.safeTypeLabel,
              hintText: editorContext.hintText);
    } catch (e) {
      return TypeGuiProviderUtils.createUnsupportedTypeEditor(this,
          labelText: editorContext.safeTypeLabel,
          hintText: editorContext.hintText,
          message: e.toString());
    }
  }

  Widget doCreateEditor(TypeEditorContext editorContext) => null;

  @override
  Widget createCompactViewer(TypeViewerContext viewerContext) {
    setupContext(viewerContext);

    try {
      if (TypeGuiProviderUtils.isWaitingForValue(viewerContext)) {
        return TypeGuiProviderUtils.createWaitingViewer(viewerContext);
      }

      // TODO createCompactViewer with valueLabel. Is this OK?
      if (viewerContext.valueLabel != null) {
        return TypeGuiProviderUtils.createTextBasedCompactViewer(
            this, viewerContext.copy()..value = viewerContext.valueLabel);
      }

      return doCreateCompactViewer(viewerContext) ??
          TypeGuiProviderUtils.createUnsupportedTypeViewer(this,
              labelText: viewerContext.safeTypeLabel);
    } catch (e) {
      return TypeGuiProviderUtils.createUnsupportedTypeViewer(this,
          labelText: viewerContext.safeTypeLabel, message: e.toString());
    }
  }

  Widget doCreateCompactViewer(TypeViewerContext viewerContext) => null;

  @override
  Widget createViewer(TypeViewerContext viewerContext) {
    setupContext(viewerContext);

    if (TypeGuiProviderUtils.isWaitingForValue(viewerContext)) {
      return TypeGuiProviderUtils.createWaitingViewer(viewerContext);
    }

    try {
      return doCreateViewer(viewerContext) ??
          TypeGuiProviderUtils.createUnsupportedTypeViewer(this,
              labelText: viewerContext.safeTypeLabel);
    } catch (e) {
      return TypeGuiProviderUtils.createUnsupportedTypeViewer(this,
          labelText: viewerContext.safeTypeLabel, message: e.toString());
    }
  }

  Widget doCreateViewer(TypeViewerContext viewerContext) => null;
  //   return _createTextBasedViewer(viewerContext);
  // }

  @override
  Widget createExtendedViewer(TypeViewerContext viewerContext) {
    setupContext(viewerContext);

    try {
      return doCreateExtendedViewer(viewerContext);
    } catch (e) {
      _logger.severe('Extended viewer error', e);
      rethrow;
    }
  }

  Widget doCreateExtendedViewer(TypeViewerContext viewerContext) => null;

  @override
  dynamic getValueFromString(String s) {
    s = s?.trim();
    if (s != null && s.isEmpty) {
      s = null;
    }
    return doGetValueFromString(s);
  }

  dynamic doGetValueFromString(String s) =>
      throw Exception('Unsupported conversion from String to ${type.kind}');

  @override
  void setupContext(UiContext uiContext) =>
      TypeGuiProviderUtils.setupContext(this, uiContext);
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
  Widget doCreateEditor(TypeEditorContext editorContext) {
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
                                  drawingBinary: oldValue)),
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

    return TypeGuiProviderUtils.createUnsupportedTypeEditor(this,
        labelText: editorContext.safeTypeLabel,
        hintText: editorContext.hintText,
        message:
            'Unsupported binary type mime=${getMimeType(editorContext)}, features=${editorContext.features}');
  }

  Future<Uint8List> _createDrawingThumbnail(DrawingBinaryValue value) async =>
      await convertImageToPng(value, width: 100);

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

    return Icon(Icons.insert_drive_file, size: 50);
  }

  @override
  Widget doCreateCompactViewer(TypeViewerContext viewerContext) {
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
  Widget doCreateViewer(TypeViewerContext viewerContext) {
    // TODO Binary viewer for images should have an option to be inline.
    return GestureDetector(
      onTap: () => navigateToExtendedViewer(viewerContext.copy()),
      child: createCompactViewer(viewerContext),
    );
  }
}

class BooleanTypeGuiProvider extends BaseUnitTypeGuiProvider<BooleanType> {
  BooleanTypeGuiProvider(DataType type) : super(type);

  @override
  Widget doCreateEditor(TypeEditorContext editorContext) {
    String widgetType = Features.getOptional(
        editorContext.features, Features.WIDGET, () => null);
    String icon = editorContext.features[Features.ICON];

    ValueChanged<bool> onChanged =
        editorContext.readOnly || !editorContext.enabled
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

    // A 'required' property doesn't matter in a case of a checkbox so it is ignored.

    Widget valueWidget;
    if (widgetType == Features.WIDGET_SWITCH &&
        !editorContext.qualifiedType.type.nullable) {
      valueWidget = wrap(Switch(
        key: Key(createDataTypeKeyValue(editorContext.qualifiedType)),
        value: editorContext.value ?? (type.nullable ? null : false),
        onChanged: onChanged,
      ));
    } else if (icon != null && !editorContext.qualifiedType.type.nullable) {
      var service = ApplicationProvider.of(editorContext.context).service;

      valueWidget = IconButton(
        key: Key(createDataTypeKeyValue(editorContext.qualifiedType)),
        icon: Icon(getIconData(service, icon)),
        onPressed: onChanged != null
            ? () => onChanged(!(editorContext.value as bool))
            : null,
      );
    } else {
      valueWidget = wrap(Checkbox(
        key: Key(createDataTypeKeyValue(editorContext.qualifiedType)),
        value: editorContext.value ?? (type.nullable ? null : false),
        onChanged: onChanged,
        tristate: type.nullable,
      ));
    }

    return valueWidget;
  }

  @override
  Widget doCreateCompactViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedCompactViewer(this, viewerContext);

  @override
  Widget doCreateViewer(TypeViewerContext viewerContext) {
    bool boolValue = viewerContext.value as bool;

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
  Widget doCreateEditor(TypeEditorContext editorContext) {
    if (editorContext.readOnly) {
      return createCompactViewer(editorContext.copyAsViewer());
    } else {
      return DateTimeEditWidget(
        key: Key(createDataTypeKeyValue(editorContext.qualifiedType)),
        name: editorContext.getDecorationLabel(),
        initialValue: editorContext.value,
        onValueChanged: editorContext.onSave,
        enabled: editorContext.enabled && !editorContext.readOnly,
      );
    }
  }

  String _valueToString(UiContext uiContext) {
    String format = TypeGuiProviderUtils.getFormat(this, uiContext);
    if (uiContext.value != null && format != null) {
      return DateFormat(format).format(uiContext.value);
    }

    return uiContext.value?.toString();
  }

  @override
  Widget doCreateCompactViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedCompactViewer(
          this, viewerContext.copy()..value = _valueToString(viewerContext));

  @override
  Widget doCreateViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedViewer(
          this, viewerContext.copy()..value = _valueToString(viewerContext));
}

class DynamicTypeGuiProvider extends BaseUnitTypeGuiProvider<DynamicType> {
  DynamicTypeGuiProvider(DataType type) : super(type);

  @override
  Widget doCreateEditor(TypeEditorContext editorContext) {
    var dynamicValue = editorContext.value as DynamicValue;

    if (dynamicValue == null) {
      return TypeGuiProviderUtils.createTextBasedCompactViewer(
          this, editorContext.copyAsViewer());
    }

    Validate.notNull(dynamicValue.type, 'A dynamic type is not set');

    QualifiedDataType qualifiedType =
        _createTargetQualifiedDataType(editorContext);

    if (editorContext.readOnly) {
      return doCreateViewer(editorContext.copyAsViewer());
    } else {
      return typeProviderRegistry
          .getProvider(dynamicValue.type)
          .createEditor(editorContext.copy()
            ..value = dynamicValue.value
            ..qualifiedType = qualifiedType);
    }
  }

  QualifiedDataType _createTargetQualifiedDataType(UiContext uiContext) =>
      QualifiedDataType(
          uiContext.qualifiedType.path, (uiContext.value as DynamicValue)?.type,
          isRoot: uiContext.qualifiedType.isRoot);

  Widget doCreateCompactViewer(TypeViewerContext viewerContext) {
    if (viewerContext.value == null) {
      return TypeGuiProviderUtils.createTextBasedCompactViewer(
          this, viewerContext);
    }

    var dynamicValue = viewerContext.value as DynamicValue;
    Validate.notNull(dynamicValue.type, 'A dynamic type is not set');

    return typeProviderRegistry
        .getProvider(dynamicValue.type)
        .createCompactViewer(viewerContext.copy()
          ..value = dynamicValue.value
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }

  @override
  Widget doCreateViewer(TypeViewerContext viewerContext) {
    if (viewerContext.value == null) {
      return TypeGuiProviderUtils.createTextBasedViewer(this, viewerContext);
    }

    var dynamicValue = viewerContext.value as DynamicValue;
    Validate.notNull(dynamicValue.type, 'A dynamic type is not set');

    return typeProviderRegistry
        .getProvider(dynamicValue.type)
        .createViewer(viewerContext.copy()
          ..value = dynamicValue.value
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }

  @override
  Widget doCreateExtendedViewer(TypeViewerContext viewerContext) {
    if (viewerContext.value == null) {
      return null;
    }

    var dynamicValue = viewerContext.value as DynamicValue;
    Validate.notNull(dynamicValue.type, 'A dynamic type is not set');

    return typeProviderRegistry
        .getProvider(dynamicValue.type)
        .createExtendedViewer(viewerContext.copy()
          ..value = dynamicValue.value
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }
}

class IntegerTypeGuiProvider extends BaseUnitTypeGuiProvider<IntegerType> {
  IntegerTypeGuiProvider(DataType type) : super(type);

  @override
  dynamic doGetValueFromString(String s) => s != null ? int.parse(s) : null;

  @override
  Widget doCreateEditor(TypeEditorContext editorContext) {
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
              key: Key(createDataTypeKeyValue(editorContext.qualifiedType)),
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

    // editorContext.labelText +=
    //     TypeGuiProviderUtils.getNumberRangeLabel(minValue, maxValue);

    return TextEditWidget(
      provider: this,
      editorContext: editorContext,
      inputType: TextInputType.numberWithOptions(decimal: false),
      validator: (value) {
        if (!type.nullable && value.isEmpty) {
          return '${editorContext.safeTypeLabel} is required';
        }

        value = value.isEmpty ? null : value;
        int intValue = value != null ? int.tryParse(value) : null;
        if (value != null && intValue == null) {
          return 'The value is not an integer';
        }

        String message = TypeGuiProviderUtils.validateNumberRange(
            intValue, minValue, exclusiveMin, maxValue, exclusiveMax);
        if (message != null) {
          return message;
        }

        return editorContext.validator != null
            ? editorContext.validator(value)
            : null;
      },
    );
  }

  @override
  Widget doCreateCompactViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedCompactViewer(this, viewerContext);

  @override
  Widget doCreateViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedViewer(this, viewerContext);
}

class ListTypeGuiProvider extends BaseUnitTypeGuiProvider<ListType> {
  ListTypeGuiProvider(DataType type) : super(type);

  //UnitTypeGuiProvider _elementTypeProvider;

  UnitTypeGuiProvider get elementTypeProvider {
    //_elementTypeProvider ??=
    return typeProviderRegistry.getProvider(type.elementType);
    //return _elementTypeProvider;
  }

  bool _useScrollableIndexedList(UiContext uiContext) =>
      ApplicationProvider.of(uiContext.context)
          .service
          .settings
          .useScrollableIndexedList;

  // TODO copy context
  @override
  Widget doCreateEditor(TypeEditorContext editorContext) {
    var hasElementValueSet = type.provided?.elementValueSet ?? false;
    if (hasElementValueSet) {
      return type.unique
          ? MultiChoiceListEditWidget(
              key: Key(createDataTypeKeyValue(editorContext.qualifiedType)),
              qType: editorContext.qualifiedType,
              labelText: editorContext.getDecorationLabel(),
              value: editorContext.value as List,
              onGetProvidedArg: editorContext.callbacks.onGetProvidedArg,
              onSave: editorContext.onSave,
              enabled: editorContext.enabled,
            )
          : null;
    } else {
      // TODO type.unique not handled in GUI.
      return ListTypeWidget(
        key: Key(createDataTypeKeyValue(editorContext.qualifiedType)),
        uiContext: editorContext,
        guiProvider: this,
        useScrollableIndexedList: _useScrollableIndexedList(editorContext),
      );
    }
  }

  // String _createListString(TypeViewerContext viewerContext) =>
  //     viewerContext.value?.toString();

  @override
  Widget doCreateCompactViewer(TypeViewerContext viewerContext) {
    return ListTypeWidget(
      key: Key(createDataTypeKeyValue(viewerContext.qualifiedType)),
      uiContext: viewerContext,
      guiProvider: this,
      useScrollableIndexedList: _useScrollableIndexedList(viewerContext),
    );

    // return TypeGuiProviderUtils.createTextBasedCompactViewer(
    //     this, viewerContext.copy()..value ??= _createListString(viewerContext));
  }

  @override
  Widget doCreateViewer(TypeViewerContext viewerContext) {
    return ListTypeWidget(
      key: Key(createDataTypeKeyValue(viewerContext.qualifiedType)),
      uiContext: viewerContext,
      guiProvider: this,
      useScrollableIndexedList: _useScrollableIndexedList(viewerContext),
    );
    // return TypeGuiProviderUtils.createTextBasedViewer(
    //     this, viewerContext.copy()..value ??= _createListString(viewerContext));
  }

  // TODO Simple list viewer. Compact viewer hack.
  // @override
  // Widget _doCreateExtendedViewer(TypeViewerContext viewerContext) {
  //   return TypeGuiProviderUtils.createTextBasedExtendedViewer(
  //       this, viewerContext.copy()..value ??= _createListString(viewerContext));
  // }
}

class MapTypeGuiProvider extends BaseUnitTypeGuiProvider<MapType> {
  MapTypeGuiProvider(DataType type) : super(type);
}

class NumberTypeGuiProvider extends BaseUnitTypeGuiProvider<NumberType> {
  NumberTypeGuiProvider(DataType type) : super(type);

  @override
  dynamic doGetValueFromString(String s) => s != null ? num.parse(s) : null;

  @override
  Widget doCreateEditor(TypeEditorContext editorContext) {
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

    // editorContext.labelText +=
    //     TypeGuiProviderUtils.getNumberRangeLabel(minValue, maxValue);

    return TextEditWidget(
      provider: this,
      editorContext: editorContext,
      inputType: TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (!type.nullable && value.isEmpty) {
          return '${editorContext.safeTypeLabel} is required';
        }

        value = value.isEmpty ? null : value;

        num numValue = value != null ? num.tryParse(value) : null;
        if (value != null && numValue == null) {
          return 'The value is not a number';
        }

        String message = TypeGuiProviderUtils.validateNumberRange(
            numValue, minValue, exclusiveMin, maxValue, exclusiveMax);
        if (message != null) {
          return message;
        }

        return editorContext.validator != null
            ? editorContext.validator(value)
            : null;
      },
    );
  }

  @override
  Widget doCreateCompactViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedCompactViewer(this, viewerContext);

  @override
  Widget doCreateViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedViewer(this, viewerContext);
}

class ObjectTypeGuiProvider extends BaseUnitTypeGuiProvider<ObjectType> {
  ObjectTypeGuiProvider(DataType type) : super(type);

  ObjectType _getObjectType(UiContext uiContext) =>
      uiContext.qualifiedType.type as ObjectType;

  @override
  Widget doCreateEditor(TypeEditorContext editorContext) {
    var objectType = _getObjectType(editorContext);

    if (objectType.companionType == null) {
      return null;
    }

    QualifiedDataType qualifiedType =
        _createTargetQualifiedDataType(editorContext);

    if (editorContext.readOnly) {
      return doCreateViewer(editorContext.copyAsViewer());
    } else {
      return typeProviderRegistry
          .getProvider(objectType.companionType)
          .createEditor(editorContext.copy()..qualifiedType = qualifiedType);
    }
  }

  QualifiedDataType _createTargetQualifiedDataType(UiContext uiContext) =>
      QualifiedDataType(uiContext.qualifiedType.path,
          (uiContext.qualifiedType.type as ObjectType).companionType,
          isRoot: uiContext.qualifiedType.isRoot);

  Widget doCreateCompactViewer(TypeViewerContext viewerContext) {
    var objectType = _getObjectType(viewerContext);

    if (objectType.companionType == null) {
      return null;
    }

    return typeProviderRegistry
        .getProvider(objectType.companionType)
        .createCompactViewer(viewerContext.copy()
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }

  @override
  Widget doCreateViewer(TypeViewerContext viewerContext) {
    var objectType = _getObjectType(viewerContext);

    if (objectType.companionType == null) {
      return null;
    }

    return typeProviderRegistry
        .getProvider(objectType.companionType)
        .createViewer(viewerContext.copy()
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }

  @override
  Widget doCreateExtendedViewer(TypeViewerContext viewerContext) {
    if (viewerContext.value == null) {
      return null;
    }

    var objectType = _getObjectType(viewerContext);

    if (objectType.companionType == null) {
      return null;
    }

    return typeProviderRegistry
        .getProvider(objectType.companionType)
        .createExtendedViewer(viewerContext.copy()
          ..qualifiedType = _createTargetQualifiedDataType(viewerContext));
  }
}

class RecordTypeGuiProvider extends BaseUnitTypeGuiProvider<RecordType> {
  RecordTypeGuiProvider(DataType type) : super(type);

  // Map<String, UnitTypeGuiProvider> _fieldTypeProviders;

  // UnitTypeGuiProvider _getFieldTypeProvider(String fieldName) {
  //   _fieldTypeProviders ??= Map.fromIterable(type.fields,
  //       key: (field) => field.name,
  //       value: (field) => typeProviderRegistry.getProvider(field.type));
  //   return _fieldTypeProviders[fieldName];
  // }

  @override
  Widget doCreateEditor(TypeEditorContext editorContext) {
    return RecordTypeWidget(
      key: Key(createDataTypeKeyValue(editorContext.qualifiedType)),
      uiContext: editorContext,
    );
  }

  // String _createRecordString(TypeViewerContext viewerContext) => viewerContext
  //             .value !=
  //         null
  //     ? '\n' +
  //         type.fields
  //             .map((field) =>
  //                 '\t${field.label ?? field.name}: ${viewerContext.value[field.name]}')
  //             .join(',\n')
  //     : null;

  @override
  Widget doCreateCompactViewer(TypeViewerContext viewerContext) {
    // Show a normal viewer.
    return doCreateViewer(viewerContext);
  }

  @override
  Widget doCreateViewer(TypeViewerContext viewerContext) {
    return RecordTypeWidget(
      key: Key(createDataTypeKeyValue(viewerContext.qualifiedType)),
      uiContext: viewerContext.copyAsEditor()..readOnly = true,
    );
  }

  // TODO Simple record viewer. Record viewer hack.
  // @override
  // Widget _doCreateExtendedViewer(TypeViewerContext viewerContext) {
  //   return _createTextBasedExtendedViewer(
  //       viewerContext.copy()..value = _createRecordString(viewerContext));
  // }

  // TODO Do not use editor with readOnly.
  // @override
  // Widget _doCreateViewer(TypeViewerContext viewerContext) => AbsorbPointer(
  //       child: _doCreateEditor(viewerContext.copyAsEditor()..readOnly = true),
  //       absorbing: true,
  //     );
}

class StreamTypeGuiProvider extends BaseUnitTypeGuiProvider<StreamType> {
  StreamTypeGuiProvider(DataType type) : super(type);
}

class StringTypeGuiProvider extends BaseUnitTypeGuiProvider<StringType> {
  StringTypeGuiProvider(DataType type) : super(type);

  @override
  dynamic doGetValueFromString(String s) => s;

  @override
  Widget doCreateEditor(TypeEditorContext editorContext) {
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
                  key: Key(createDataTypeKeyValue(editorContext.qualifiedType)),
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
      default:
        bool multiline = Features.getOptional(
            editorContext.features, Features.STRING_MULTILINE, () => false);
        int maxLines = Features.getOptional(editorContext.features,
            Features.STRING_MAX_LINES, () => multiline ? null : 1);
        TextInputType inputType = (multiline || maxLines > 1)
            ? TextInputType.multiline
            : TextInputType.text;

        switch (TypeGuiProviderUtils.getFormat(this, editorContext)) {
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
          provider: this,
          editorContext: editorContext,
          inputType: inputType,
          validator: (value) {
            if (minLength != null && value.length < minLength) {
              return 'The text is shorter than $minLength';
            }

            if (maxLength != null && value.length > maxLength) {
              return 'The text is longer than $maxLength';
            }

            if (editorContext.validator != null) {
              String validationMessage = editorContext.validator(value);
              if (validationMessage != null) {
                return validationMessage;
              }
            }

            return null;
          },
          maxLines: maxLines,
        );
    }
  }

  @override
  Widget doCreateCompactViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedCompactViewer(this, viewerContext);

  @override
  Widget doCreateViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedViewer(this, viewerContext);

  @override
  Widget doCreateExtendedViewer(TypeViewerContext viewerContext) {
    return TypeGuiProviderUtils.createTextBasedExtendedViewer(
        this, viewerContext);
  }
}

class TypeTypeGuiProvider extends BaseUnitTypeGuiProvider<TypeType> {
  TypeTypeGuiProvider(DataType type) : super(type);
}

class VoidTypeGuiProvider extends BaseUnitTypeGuiProvider<VoidType> {
  VoidTypeGuiProvider(DataType type) : super(type);

  @override
  Widget doCreateEditor(TypeEditorContext editorContext) {
    String icon = editorContext.features[Features.ICON];

    var onTap = editorContext.enabled &&
            !editorContext.readOnly &&
            (editorContext.qualifiedType.type.provided?.submittable ?? false)
        ? () => editorContext.onSave(null)
        : null;

    if (icon != null) {
      var service = ApplicationProvider.of(editorContext.context).service;

      return IconButton(
        key: Key(createDataTypeKeyValue(editorContext.qualifiedType)),
        icon: Icon(getIconData(service, icon)),
        onPressed: onTap,
      );
    }
    return GestureDetector(
      child: Chip(
        label: Text(editorContext.typeLabel ?? ''),
      ),
      onTap: onTap,
    );
  }

  Widget doCreateCompactViewer(TypeViewerContext viewerContext) =>
      TypeGuiProviderUtils.createTextBasedCompactViewer(
          this, viewerContext.copy()..value = 'Success');
}
