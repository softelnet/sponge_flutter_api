import 'package:logging/logging.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/bloc/provide_action_args_state.dart';
import 'package:sponge_flutter_api/src/common/model/action_call_session.dart';
import 'package:sponge_flutter_api/src/common/ui/base_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/flutter_model.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/ui_context.dart';
import 'package:sponge_flutter_api/src/util/utils.dart';

class ActionCallViewModel extends BaseViewModel {
  ActionCallViewModel(this.actionData);

  ActionData actionData;
}

abstract class ActionCallView extends BaseView {
  void refresh();
  Future<void> refreshArgs({bool modal, bool showDialogOnError});
  Future<bool> saveForm();
  Future<void> onBeforeSubActionCall();
  Future<void> onAfterSubActionCall(ActionCallState state);
}

class ActionCallPresenter
    extends BasePresenter<ActionCallViewModel, ActionCallView>
    implements UiContextCallbacks {
  ActionCallPresenter(ActionCallViewModel viewModel, ActionCallView view)
      : super(viewModel, view);

  static final Logger _logger = Logger('ActionCallPresenter');
  bool busy = false;
  bool get callable => actionMeta.callable ?? true;

  ActionCallSession _session;

  ActionCallSession get session => _session;

  bool get anyArgSavedOrUpdated => _session.anyArgSavedOrUpdated;

  dynamic error;

  void init({bool verifyIsActive = true}) {
    _session = ActionCallSession(
      service.spongeService,
      viewModel.actionData,
      onEventReceived: (event) => view.refreshArgs(
        modal: false,
        // TODO Is preventing error dialog in an event subscription OK? Maybe a snackbar should be shown.
        showDialogOnError: false,
      ),
      defaultPageableListPageSize: service.settings.defaultPageableListPageSize,
      verifyIsActive: verifyIsActive,
    );

    _session.open();
  }

  void ensureRunning() {
    _session.ensureRunning();
  }

  Stream<ProvideActionArgsState> provideArgs() async* {
    yield* _session.provideArgs();
  }

  Future<bool> refreshAllowedProvidedArgs() async =>
      await _session.refreshAllowedProvidedArgs();

  String get connectionName => service.spongeService?.connection?.name;

  ActionData get actionData => viewModel.actionData;

  ActionMeta get actionMeta => actionData.actionMeta;

  String get actionLabel => getActionMetaDisplayLabel(actionData.actionMeta);

  void clearArgs() {
    _session.clearArgs();
  }

  bool get hasProvidedArgs => _session.hasProvidedArgs;

  bool get hasRefreshableArgs => _session.hasRefreshableArgs;

  void validateArgs() => service.spongeService.client
      .validateCallArgs(actionMeta, actionData.args);

  bool get showCall => DataTypeGuiUtils.showCall(actionMeta);

  bool get showRefresh => DataTypeGuiUtils.showRefresh(actionMeta);

  bool get showClear => DataTypeGuiUtils.showClear(actionMeta);

  bool get showCancel => DataTypeGuiUtils.showCancel(actionMeta);

  String get callLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_CALL_LABEL, () => 'RUN');

  String get refreshLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_REFRESH_LABEL, () => 'REFRESH');

  String get clearLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_CLEAR_LABEL, () => 'CLEAR');

  String get cancelLabel => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_CANCEL_LABEL, () => 'CANCEL');

  void close() {
    _session.close();
  }

  bool isScrollable() {
    return !actionMeta.args
        .any((arg) => DataTypeGuiUtils.hasListTypeScroll(arg));
  }

  bool get canSwipeToClose =>
      // TODO Is checking the record single leading field for swipe to close ok? Swipe shpuld be disabled for maps.
      service.settings.actionSwipeToClose &&
      !(DataTypeGuiUtils.getRootRecordSingleLeadingFieldByAction(actionData)
              ?.features
              ?.containsKey(Features.GEO_MAP) ??
          false);

  bool hasRootRecordSingleLeadingField() =>
      DataTypeGuiUtils.getRootRecordSingleLeadingFieldByAction(actionData) !=
      null;

  Future<bool> isActionActive() async => await _session.isActionActive();

  // Callbacks.
  void _onSaveOrUpdate(
      QualifiedDataType qType, dynamic value, bool refreshView) {
    if (_session.saveOrUpdate(qType, value)) {
      if (refreshView) {
        view.refresh();
      }
    }
  }

  @override
  void onSave(QualifiedDataType qType, dynamic value) {
    _onSaveOrUpdate(qType, value, true);
  }

  @override
  void onUpdate(QualifiedDataType qType, dynamic value) {
    bool responsive = DataTypeUtils.getFeatureOrProperty(
        qType.type, value, Features.RESPONSIVE, () => false);

    _onSaveOrUpdate(qType, value, responsive);
  }

  @override
  void onActivate(QualifiedDataType qType, value) {
    if (_session.activate(qType, value)) {
      view.refresh();
    }
  }

  @override
  ProvidedValue onGetProvidedArg(QualifiedDataType qType) =>
      _session.getProvidedArg(qType);

  @override
  bool shouldBeEnabled(QualifiedDataType qType) =>
      _session.shouldBeEnabled(qType);

  @override
  Future<void> onRefresh() async => view.refresh();

  @override
  Future<void> onRefreshArgs() async {
    await view.refreshArgs();
  }

  @override
  Future<bool> onSaveForm() async => await view.saveForm();

  @override
  Future<void> onBeforeSubActionCall() async {
    await view.onBeforeSubActionCall();
  }

  @override
  Future<void> onAfterSubActionCall(ActionCallState state) async {
    await view.onAfterSubActionCall(state);
  }

  @override
  PageableList getPageableList(QualifiedDataType qType) =>
      actionData.getPageableList(qType.path);

  @override
  Future<void> fetchPageableListPage(QualifiedDataType listQType) async =>
      await _session.fetchPageableListPage(listQType);

  @override
  String getKey(String code) {
    if (code == null) {
      return null;
    }

    try {
      return actionData.getArgValueByName(code,
          unwrapAnnotatedTarget: true, unwrapDynamicTarget: true);
    } catch (e) {
      // TODO Handle the exception properly.
      _logger.severe('getKey error for \'$code\'', e);
      return null;
    }
  }

  @override
  dynamic getAdditionalData(
          QualifiedDataType qType, String additionalDataKey) =>
      (actionData as FlutterActionData)
          .getAdditionalArgData(qType.path, additionalDataKey);

  @override
  void setAdditionalData(
      QualifiedDataType qType, String additionalDataKey, dynamic value) {
    (actionData as FlutterActionData)
        .setAdditionalArgData(qType.path, additionalDataKey, value);
  }

  @override
  FlutterApplicationService get service => super.service;
}
