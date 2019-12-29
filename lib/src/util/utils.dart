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

import 'package:sponge_client_dart/sponge_client_dart.dart';

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
      Features.getOptional(t.features, Features.SCROLL, () => false);

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
