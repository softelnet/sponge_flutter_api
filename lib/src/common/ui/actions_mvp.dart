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
import 'package:sponge_flutter_api/src/common/bloc/connection_state.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/base_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/util/utils.dart';

class ActionsViewModel extends BaseViewModel {}

class SpongeConnectionViewModel {
  SpongeConnectionViewModel(this.name, this.isActive);

  String name;
  bool isActive;
}

abstract class ActionsView extends BaseView {
  Future<bool> showActionCallConfirmationDialog(ActionData actionData);
  Future<ActionData> showActionCallScreen(ActionData actionData);
}

class ActionsPresenter extends BasePresenter<ActionsViewModel, ActionsView> {
  ActionsPresenter(ActionsView view) : super(ActionsViewModel(), view);

  List<SpongeConnectionViewModel> getConnections(
      bool isFilterByNetwork, String network) {
    return service.connectionsConfiguration
        .getConnections()
        .where((connection) =>
            !isFilterByNetwork ||
            shouldConnectionBeFiltered(connection, network))
        .map((connection) => SpongeConnectionViewModel(
            connection.name, service.isConnectionActive(connection.name)))
        .toList();
  }

  bool get hasConnections => service.hasConnections;

  SpongeConnection get connection => service.spongeService?.connection;

  String get connectionName => service.spongeService?.connection?.name;

  bool get connected => service.connected;

  bool busy = false;

  Future<List<ActionData>> getActions() async {
    List<ActionData> actionDataList = (await service.spongeService.getActions())
        .where((actionData) => actionData.isVisible)
        // Filter out actions with handled intents.
        .where((actionData) =>
            service.spongeService
                ?.isActionAllowedByIntent(actionData.actionMeta) ??
            true)
        // Filter out unsupported actions.
        .where((actionData) =>
            service.spongeService?.isActionSupported(actionData.actionMeta) ??
            true)
        .toList();

    // Sort actions.
    if (service.settings.actionsOrder == ActionsOrder.alphabetical) {
      actionDataList.sort((a1, a2) =>
          getQualifiedActionDisplayLabel(a1.actionMeta)
              .compareTo(getQualifiedActionDisplayLabel(a2.actionMeta)));
    }
    return actionDataList;
  }

  Future<void> refreshActions() async {
    if (service.connectionBloc.state is SpongeConnectionStateConnected) {
      await service.spongeService.clearActions();
    } else if (connectionName != null) {
      await service.setActiveConnection(connectionName, forceRefresh: true);
    }
  }

  Future<void> onConnectionChange(String connectionName) async {
    await service.setActiveConnection(connectionName);
  }

  Future<void> onActionCall(ActionData actionData) async {
    if (actionData.actionMeta.args.isEmpty && !actionData.actionMeta.callable) {
      return;
    }

    if (actionData.needsRunConfirmation) {
      if (!await view.showActionCallConfirmationDialog(actionData)) {
        return;
      }
    }

    if (actionData.actionMeta.args.isNotEmpty) {
      ActionData newActionData = await view.showActionCallScreen(actionData);
      if (newActionData == null) {
        return;
      }
      actionData.args = newActionData.args;
    }

    var bloc =
        service.spongeService.getActionCallBloc(actionData.actionMeta.name);
    bloc.onActionCall.add(actionData.args ?? []);
  }
}
