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

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/sponge_flutter_api.dart';

typedef VoidFutureOrCallback = FutureOr<void> Function();

String substring(String s, int maxLength) => s != null && s.length > maxLength
    ? s.substring(0, maxLength).trim() + '...'
    : s;

String getActionMetaDisplayLabel(ActionMeta actionMeta) =>
    actionMeta.label ?? actionMeta.name;

String getSafeTypeDisplayLabel(DataType type) => type.label ?? type.name;

String getActionGroupDisplayLabel(ActionMeta actionMeta) =>
    actionMeta.category?.label ??
    actionMeta.category?.name ??
    actionMeta.knowledgeBase?.label ??
    actionMeta.knowledgeBase?.name;

/// Returns the qualified action label (category or knowledge base: action).
String getQualifiedActionDisplayLabel(ActionMeta actionMeta) {
  return '${getActionGroupDisplayLabel(actionMeta)}: ${getActionMetaDisplayLabel(actionMeta)}';
}

/// Returns `null` if not found.
DataType getActionArgByIntent(ActionMeta actionMeta, String intentValue) =>
    actionMeta.args.firstWhere(
        (arg) =>
            arg.features[Features.INTENT] == intentValue ||
            arg.name == intentValue,
        orElse: () => null);

class DataTypeGuiUtils {
  static bool hasType(
    DataType type,
    bool Function(DataType) predicate, {
    bool recursively = false,
  }) {
    if (recursively) {
      bool result = false;

      DataTypeUtils.traverseDataType(QualifiedDataType(type),
          (QualifiedDataType qType) {
        if (predicate(qType.type)) {
          result = true;
        }
      }, namedOnly: false, traverseCollections: true);

      return result;
    } else {
      return predicate(type);
    }
  }

  static bool hasListTypeScroll(DataType type) {
    var predicate = (DataType t) =>
        t is ListType &&
        (Features.getOptional(t.features, Features.SCROLL, () => false) ||
            Features.getOptional(
                t.features, Features.PROVIDE_VALUE_PAGEABLE, () => false));
    return hasType(type, predicate);
  }

  static RootRecordSingleLeadingField getRootRecordSingleLeadingFieldByAction(
      ActionData actionData) {
    var recordType = actionData.argsAsRecordType;
    var rootRecordSingleLeadingField = getRootRecordSingleLeadingField(
        QualifiedDataType(recordType), actionData.argsAsRecord);

    if (rootRecordSingleLeadingField != null) {
      // If the action has buttons, it cannot have the record single leading field.
      var actionMeta = actionData.actionMeta;
      if (actionMeta.callable && showCall(actionMeta) ||
          showRefresh(actionMeta) ||
          showClear(actionMeta) ||
          showCancel(actionMeta)) {
        return null;
      }
    }

    return rootRecordSingleLeadingField;
  }

  static RootRecordSingleLeadingField getRootRecordSingleLeadingField(
      QualifiedDataType qualifiedRecordType, Map recordValue) {
    if (!(qualifiedRecordType.type is RecordType)) {
      return null;
    }

    var recordType = qualifiedRecordType.type as RecordType;

    if (qualifiedRecordType.isRoot && recordType.fields.length == 1) {
      var fieldType = recordType.fields[0];
      var fieldValue = recordValue[fieldType.name];
      var fieldFeatures = DataTypeUtils.mergeFeatures(fieldType, fieldValue);

      // TODO Better check.
      if (fieldFeatures[Features.GEO_MAP] != null) {
        return RootRecordSingleLeadingField(
            qualifiedRecordType.createChild(fieldType),
            fieldValue,
            fieldFeatures);
      }
    }

    return null;
  }

  static bool showCall(ActionMeta actionMeta) => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_SHOW_CALL, () => true);

  static bool showRefresh(ActionMeta actionMeta) => Features.getOptional(
      actionMeta.features,
      Features.ACTION_CALL_SHOW_REFRESH,
      () => actionMeta.features[Features.ACTION_CALL_REFRESH_LABEL] != null);

  static bool showClear(ActionMeta actionMeta) => Features.getOptional(
      actionMeta.features,
      Features.ACTION_CALL_SHOW_CLEAR,
      () => actionMeta.features[Features.ACTION_CALL_CLEAR_LABEL] != null);

  static bool showCancel(ActionMeta actionMeta) => Features.getOptional(
      actionMeta.features,
      Features.ACTION_CALL_SHOW_CANCEL,
      () => actionMeta.features[Features.ACTION_CALL_CANCEL_LABEL] != null);
}

PageRoute<T> createPageRoute<T>(
  BuildContext context, {
  @required WidgetBuilder builder,
  String title,
  RouteSettings settings,
  bool maintainState = true,
  bool fullscreenDialog = false,
}) =>
    ApplicationProvider.of(context).service.settings.actionSwipeToClose
        ? CupertinoPageRoute<T>(
            builder: builder,
            title: title,
            settings: settings,
            maintainState: maintainState,
            fullscreenDialog: fullscreenDialog)
        : MaterialPageRoute<T>(
            builder: builder,
            settings: settings,
            maintainState: maintainState,
            fullscreenDialog: fullscreenDialog);

class DefaultDrawerHeader extends StatelessWidget {
  DefaultDrawerHeader({
    Key key,
    @required this.applicationName,
  }) : assert(applicationName != null);

  final String applicationName;

  @override
  Widget build(BuildContext context) {
    return DrawerHeader(
      child: Column(
        children: [
          Image.asset('assets/images/logo.png', fit: BoxFit.scaleDown),
          Container(
            alignment: Alignment.centerRight,
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                return Text(
                    snapshot.hasData
                        ? '$applicationName, ver. ${snapshot.data.version}'
                        : '',
                    style: DefaultTextStyle.of(context)
                        .style
                        .apply(color: Colors.white)
                        .apply(fontSizeFactor: 1.2));
              },
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        color: isDarkTheme(context)
            ? Theme.of(context).dialogBackgroundColor
            : Theme.of(context).accentColor,
        image: DecorationImage(
            image: AssetImage('assets/images/banner.png'), fit: BoxFit.cover),
      ),
    );
  }
}

class RootRecordSingleLeadingField {
  RootRecordSingleLeadingField(this.qType, this.fieldValue, this.features);

  QualifiedDataType qType;
  dynamic fieldValue;
  Map<String, Object> features;
}

class IconTextPopupMenuItemWidget extends StatelessWidget {
  const IconTextPopupMenuItemWidget({
    Key key,
    @required this.icon,
    @required this.text,
    this.isOn,
  }) : super(key: key);

  final IconData icon;
  final String text;
  final bool isOn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Icon(
            icon,
            color: (isOn ?? true)
                ? getSecondaryColor(context)
                : getThemedBackgroundColor(context),
          ),
        ),
        Expanded(
          child: Text(text),
        ),
      ],
    );
  }
}
