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
}
