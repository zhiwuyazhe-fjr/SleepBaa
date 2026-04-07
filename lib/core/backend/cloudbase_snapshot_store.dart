import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_app_api_client.dart';

class CloudBaseSnapshotStore extends ChangeNotifier {
  CloudBaseSnapshotStore({required CloudBaseAppApiClient appApiClient})
    : _appApiClient = appApiClient;

  final CloudBaseAppApiClient _appApiClient;

  Map<String, dynamic> _payload = <String, dynamic>{};
  bool _isRefreshing = false;
  String? _lastError;

  Map<String, dynamic> get payload => _payload;
  bool get isRefreshing => _isRefreshing;
  String? get lastError => _lastError;
  bool get hasPayload => _payload.isNotEmpty;

  Future<void> refresh() async {
    if (_isRefreshing || !_appApiClient.isConfigured) {
      return;
    }
    _isRefreshing = true;
    _lastError = null;
    notifyListeners();
    try {
      _payload = await _appApiClient.bootstrap();
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void clear() {
    _payload = <String, dynamic>{};
    _lastError = null;
    notifyListeners();
  }
}
