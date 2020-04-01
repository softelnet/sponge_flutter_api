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

import 'package:flutter/material.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/ui_context.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/view_widgets.dart';

class TypeGuiProviderUtils {
  static const UNSUPPORTED_BACKGROUND_COLOR = Colors.yellow;
  static const UNSUPPORTED_TEXT_COLOR = Colors.red;
  static const double PADDING = 10.0;
  static const int LABEL_MAX_LENGTH = 200;

  static String getFormat<T extends DataType>(
    UnitTypeGuiProvider<T> provider,
    UiContext uiContext,
  ) =>
      DataTypeUtils.getFeatureOrProperty(provider.type, uiContext.value,
          DataType.FEATURE_FORMAT, () => provider.type.format);

  static Widget createUnsupportedTypeEditor<T extends DataType>(
    UnitTypeGuiProvider<T> provider, {
    @required String labelText,
    @required String hintText,
    String message,
  }) {
    message = message ?? 'Unsupported type ${provider.type.kindValue}';
    return Tooltip(
      message: message,
      child: TextFormField(
        keyboardType: TextInputType.text,
        enabled: false,
        style: TextStyle(
            color: UNSUPPORTED_TEXT_COLOR, fontWeight: FontWeight.bold),
        initialValue: message,
        decoration: InputDecoration(
          border: const UnderlineInputBorder(),
          filled: true,
          //fillColor: UNSUPPORTED_BACKGROUND_COLOR,
          labelText: labelText,
          hintText: hintText,
        ),
        maxLines: null,
      ),
    );
  }

  static String obscure(String text) => text?.replaceAll(RegExp(r'.'), '*');

  static Widget createTextBasedCompactViewer<T extends DataType>(
    UnitTypeGuiProvider<T> provider,
    TypeViewerContext viewerContext,
  ) {
    return createTextBasedViewer(
      provider,
      viewerContext,
      maxLength: LABEL_MAX_LENGTH,
      compact: true,
      showLabel: viewerContext.showLabel,
    );
  }

  static Widget createTextBasedExtendedViewer<T extends DataType>(
    UnitTypeGuiProvider<T> provider,
    TypeViewerContext viewerContext,
  ) {
    String stringValue =
        viewerContext.valueLabel ?? viewerContext.value?.toString();

    if (stringValue == null || stringValue.length < LABEL_MAX_LENGTH) {
      return null;
    }

    return ExtendedTextViewWidget(
        textViewer:
            createTextBasedViewer(provider, viewerContext, showLabel: false));
  }

  static Widget createTextBasedViewer<T extends DataType>(
    UnitTypeGuiProvider<T> provider,
    TypeViewerContext viewerContext, {
    int maxLength = -1,
    bool compact = false,
    bool showLabel = true,
  }) {
    String stringValue =
        viewerContext.valueLabel ?? viewerContext.value?.toString();
    if (Features.getOptional(
        viewerContext.features, Features.STRING_OBSCURE, () => false)) {
      stringValue = obscure(stringValue);
    }

    var label = viewerContext.getDecorationLabel();

    return TextViewWidget(
      key: createDataTypeKey(viewerContext.qualifiedType),
      label: label,
      text: stringValue,
      format: getFormat(provider, viewerContext),
      maxLength: maxLength,
      compact: compact,
      showLabel: showLabel && label != null,
    );
  }

  static Widget createUnsupportedTypeViewer<T extends DataType>(
    UnitTypeGuiProvider<T> provider, {
    @required String labelText,
    String message,
  }) {
    message = message ?? 'Unsupported type ${provider.type.kindValue}';
    return Text(
      '$labelText: $message',
      style: TextStyle(color: UNSUPPORTED_TEXT_COLOR),
    );
  }

  static Widget createWaitingViewer(UiContext viewerContext) {
    return Column(
      children: <Widget>[
        Align(
          child: Text(
            viewerContext.getDecorationLabel() ?? '',
            style: getArgLabelTextStyle(viewerContext.context),
          ),
          alignment: Alignment.centerLeft,
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  static String getNumberRangeLabel(num min, num max) {
    if (min == null && max == null) {
      return '';
    }

    String range = ' [';
    if (min != null) {
      range += '$min';
    }
    range += '-';
    if (max != null) {
      range += '$max';
    }
    range += ']';
    return range;
  }

  static String validateNumberRange(
      num value, num min, bool exclusiveMin, num max, bool exclusiveMax) {
    String message = validateNumberMin(value, min, exclusiveMin);
    if (message != null) {
      return message;
    }

    message = validateNumberMax(value, max, exclusiveMax);
    if (message != null) {
      return message;
    }

    return null;
  }

  static String validateNumberMin(num value, num min, bool exclusiveMin) {
    if (min == null ||
        exclusiveMin && value > min ||
        !exclusiveMin && value >= min) {
      return null;
    }

    return 'The value must be greater than ${exclusiveMin ? "" : " or equal to "} $min';
  }

  static String validateNumberMax(num value, num max, bool exclusiveMax) {
    if (max == null ||
        exclusiveMax && value < max ||
        !exclusiveMax && value <= max) {
      return null;
    }

    return 'The value must be lower than ${exclusiveMax ? "" : " or equal to "} $max';
  }
}
