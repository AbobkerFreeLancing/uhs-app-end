import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// خدمة مراقبة حالة الاتصال بالإنترنت
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionStatusController.stream;
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// بدء مراقبة الاتصال
  void startMonitoring() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final connected = results.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet);
      if (connected != _isConnected) {
        _isConnected = connected;
        _connectionStatusController.add(_isConnected);
      }
    });

    // فحص الحالة الحالية مباشرةً عند البدء
    checkConnectivity();
  }

  /// فحص الاتصال الحالي مرة واحدة
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isConnected = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
    _connectionStatusController.add(_isConnected);
    return _isConnected;
  }

  /// إيقاف المراقبة وتنظيف الموارد
  void dispose() {
    _subscription?.cancel();
    _connectionStatusController.close();
  }
}
