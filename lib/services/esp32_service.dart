import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gps_data.dart';

enum ConnectionQuality { excellent, good, fair, poor, disconnected }

class Esp32Service {
  static const String _ipKey = 'esp32_ip';
  static const int _wsPort = 81;
  static const int _httpPort = 80;
  static const Duration _timeout = Duration(seconds: 5);
  static const int _maxReconnectDelay = 30; // seconds

  String _deviceIp = '192.168.1.100';
  WebSocketChannel? _wsChannel;
  StreamController<GpsData>? _gpsStreamController;
  StreamController<DeviceStatus>? _statusStreamController;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  int _successCount = 0;
  int _failureCount = 0;
  int _healthFailCount = 0;
  ConnectionQuality _connectionQuality = ConnectionQuality.disconnected;

  StreamController<ConnectionQuality>? _connectionController;

  // Getters
  String get deviceIp => _deviceIp;
  bool get isConnected => _isConnected;
  int get reconnectAttempts => _reconnectAttempts;
  int get successCount => _successCount;
  int get failureCount => _failureCount;
  ConnectionQuality get connectionQuality => _connectionQuality;
  Stream<GpsData>? get gpsStream => _gpsStreamController?.stream;
  Stream<DeviceStatus>? get statusStream => _statusStreamController?.stream;
  Stream<ConnectionQuality>? get connectionStream =>
      _connectionController?.stream;

  Future<void> init() async {
    _gpsStreamController = StreamController<GpsData>.broadcast();
    _statusStreamController = StreamController<DeviceStatus>.broadcast();
    _connectionController = StreamController<ConnectionQuality>.broadcast();

    final prefs = await SharedPreferences.getInstance();
    _deviceIp = prefs.getString(_ipKey) ?? '192.168.1.100';
  }

  Future<void> setDeviceIp(String ip) async {
    _deviceIp = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, ip);
  }

  String get _httpBase => 'http://$_deviceIp:$_httpPort';
  String get _wsUrl => 'ws://$_deviceIp:$_wsPort';

  void _updateQuality() {
    final total = _successCount + _failureCount;
    if (total == 0 || !_isConnected) {
      _connectionQuality = ConnectionQuality.disconnected;
    } else {
      final rate = _successCount / total;
      if (rate >= 0.95) {
        _connectionQuality = ConnectionQuality.excellent;
      } else if (rate >= 0.85) {
        _connectionQuality = ConnectionQuality.good;
      } else if (rate >= 0.7) {
        _connectionQuality = ConnectionQuality.fair;
      } else {
        _connectionQuality = ConnectionQuality.poor;
      }
    }
    _connectionController?.add(_connectionQuality);
  }

  /// Test connection to ESP32
  Future<bool> testConnection() async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(Uri.parse('$_httpBase/ping'))
          .timeout(_timeout);
      stopwatch.stop();
      if (response.statusCode == 200) {
        _successCount++;
        _updateQuality();
        return true;
      }
      _failureCount++;
      _updateQuality();
      return false;
    } catch (e) {
      _failureCount++;
      _updateQuality();
      return false;
    }
  }

  /// Health check — returns detailed system health map or null
  Future<Map<String, dynamic>?> getHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_httpBase/health'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        _healthFailCount = 0;
        _successCount++;
        _updateQuality();
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    _healthFailCount++;
    _failureCount++;
    _updateQuality();
    return null;
  }

  /// Connect via WebSocket (real-time streaming)
  Future<void> connectWebSocket() async {
    await disconnectWebSocket();
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _wsChannel!.stream.listen(
        (data) {
          _handleWsMessage(data as String);
        },
        onError: (error) {
          _isConnected = false;
          _failureCount++;
          _updateQuality();
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _updateQuality();
          _scheduleReconnect();
        },
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _successCount++;
      _updateQuality();
    } catch (e) {
      _isConnected = false;
      _failureCount++;
      _updateQuality();
      _scheduleReconnect();
    }
  }

  void _handleWsMessage(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'gps') {
        final gps = GpsData.fromJson(json['data'] as Map<String, dynamic>);
        _gpsStreamController?.add(gps);
      } else if (type == 'status') {
        final status =
            DeviceStatus.fromJson(json['data'] as Map<String, dynamic>);
        _statusStreamController?.add(status);
      }
    } catch (_) {}
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delay = (_reconnectAttempts * 2).clamp(1, _maxReconnectDelay);
    _reconnectTimer = Timer(Duration(seconds: delay), connectWebSocket);
  }

  /// Fallback: poll via HTTP every N seconds
  void startHttpPolling({int intervalSeconds = 2}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _fetchGpsHttp(),
    );
  }

  void stopHttpPolling() => _pollTimer?.cancel();

  Future<void> _fetchGpsHttp() async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(Uri.parse('$_httpBase/gps'))
          .timeout(_timeout);
      stopwatch.stop();

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final gps = GpsData.fromJson(json);
        _gpsStreamController?.add(gps);
        _isConnected = true;
        _successCount++;
        _updateQuality();
      }
    } catch (_) {
      _isConnected = false;
      _failureCount++;
      _updateQuality();
    }
  }

  Future<GpsData?> getGpsOnce() async {
    try {
      final response = await http
          .get(Uri.parse('$_httpBase/gps'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return GpsData.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  Future<DeviceStatus?> getDeviceStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$_httpBase/status'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return DeviceStatus.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  Future<void> disconnectWebSocket() async {
    _reconnectTimer?.cancel();
    await _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnected = false;
    _updateQuality();
  }

  Future<void> dispose() async {
    await disconnectWebSocket();
    stopHttpPolling();
    await _gpsStreamController?.close();
    await _statusStreamController?.close();
    await _connectionController?.close();
  }
}
