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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/sponge_flutter_api.dart';

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

bool hasListTypeScroll(DataType type, {bool recursively = false}) {
  var check = (DataType t) =>
      t is ListType &&
      (Features.getOptional(t.features, Features.SCROLL, () => false) ||
          Features.getOptional(
              t.features, Features.PROVIDE_VALUE_PAGEABLE, () => false));

  if (recursively) {
    bool hasScroll = false;

    DataTypeUtils.traverseDataType(QualifiedDataType(null, type),
        (QualifiedDataType qType) {
      if (check(qType.type)) {
        hasScroll = true;
      }
    }, namedOnly: false, traverseCollections: true);

    return hasScroll;
  } else {
    return check(type);
  }
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
            color: (isOn ?? true) ? getSecondaryColor(context) : getThemedBackgroundColor(context),
          ),
        ),
        Expanded(
          child: Text(text),
        ),
      ],
    );
  }
}
