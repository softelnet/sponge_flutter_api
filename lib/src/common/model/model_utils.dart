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

import 'package:flutter/widgets.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';
import 'package:sponge_flutter_api/src/common/util/utils.dart';

class ModelUtils {
  static List<dynamic> substituteSubActionArgs(
    SpongeService spongeService,
    SubActionSpec subActionSpec,
    DataType sourceType,
    dynamic sourceValue, {
    @required bool propagateContextActions,
    bool bestEffort = false,
  }) {
    ActionMeta subActionMeta =
        spongeService.getCachedAction(subActionSpec.actionName).actionMeta;
    var subActionData = ActionData(subActionMeta);

    bool showActionCallWidget = subActionMeta.args.length >
        (subActionSpec.argSubstitutions?.length ?? 1);

    if (subActionSpec.argSubstitutions == null) {
      // The default behavior that sets the first arg of the sub-action, if any.
      if (subActionMeta.args.isNotEmpty) {
        try {
          // TODO More strict sub-action arg validation.
          Validate.isTrue(subActionMeta.args[0].kind == sourceType.kind,
              'The first argument of ${subActionMeta.name} action should be ${sourceType.kind}');
          subActionData.args[0] = DataTypeUtils.cloneValue(sourceValue);
        } catch (e) {
          if (!bestEffort) {
            rethrow;
          }
        }
      }
    } else {
      for (var i = 0; i < subActionData.args.length; i++) {
        var subArgType = subActionMeta.args[i];

        var subActionArgSpec = subActionSpec.argSubstitutions.firstWhere(
            (substitution) => substitution.target == subArgType.name,
            orElse: () => null);
        if (subActionArgSpec != null) {
          try {
            subActionData.args[i] = DataTypeUtils.cloneValue(
                DataTypeUtils.getSubValue(sourceValue, subActionArgSpec.source,
                    unwrapAnnotatedTarget: false, unwrapDynamicTarget: false));
          } catch (e) {
            if (!bestEffort) {
              rethrow;
            }
          }
        }
      }
    }

    if (!bestEffort) {
      for (var i = 0; i < subActionData.args.length; i++) {
        var subArgType = subActionMeta.args[i];

        var subActionArgSpec = subActionSpec.argSubstitutions?.firstWhere(
            (substitution) => substitution.target == subArgType.name,
            orElse: () => null);

        Validate.isTrue(
            Features.getOptional(
                        subArgType.features, Features.VISIBLE, () => true) &&
                    showActionCallWidget ||
                subArgType.nullable ||
                DataTypeUtils.hasAllNotNullValuesSet(
                    subArgType, subActionData.args[i]),
            // TODO Support context actions in dynamic types.
            subActionArgSpec != null
                ? 'The argument \'${getSafeTypeDisplayLabel(DataTypeUtils.getSubType(sourceType, subActionArgSpec.source, null))}\' is not set properly'
                : 'The sub-action argument \'${getSafeTypeDisplayLabel(subArgType)}\' is not set properly');
      }
    }

    // Do not propagate context actions to sub-actions.
    subActionData.args = subActionData.args.map((arg) {
      if (arg is AnnotatedValue && !propagateContextActions) {
        arg = AnnotatedValue.of(arg)
          ..features
              .removeWhere((name, value) => name == Features.CONTEXT_ACTIONS);
      }

      return arg;
    }).toList();

    return subActionData.args;
  }
}
