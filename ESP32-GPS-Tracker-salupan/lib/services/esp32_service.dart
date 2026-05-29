import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gps_data.dart';
import '../utils/validators.dart';


class Esp32Service {
  static const String _ipKey = 'esp32_ip';
  static const int _wsPort = 81;
  static const int _httpPort = 80;
  static const Duration _timeout = Duration(seconds: 5);

  String _deviceIp = '192.168.1.100';
  WebSocketChannel? _wsChannel;
  StreamController<GpsData>? _gpsStreamController;
  StreamController<DeviceStatus>? _statusStreamController;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  bool _isConnected = false;

  // Getters
  String get deviceIp => _deviceIp;
  bool get isConnected => _isConnected;
  Stream<GpsData>? get gpsStream => _gpsStreamController?.stream;
  Stream<DeviceStatus>? get statusStream => _statusStreamController?.stream;

  Future<void> init() async {
    _gpsStreamController = StreamController<GpsData>.broadcast();
    _statusStreamController = StreamController<DeviceStatus>.broadcast();

    final prefs = await SharedPreferences.getInstance();
    _deviceIp = prefs.getString(_ipKey) ?? '192.168.1.100';
  }

  Future<void> setDeviceIp(String ip) async {
    _deviceIp = ip;
    final sanitized = Validators.sanitizeInput(ip) ?? ip;
    final validated = Validators.validateIp(sanitized);
    _deviceIp = validated == null ? sanitized : '192.168.1.100';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, ip);
    await prefs.setString(_ipKey, _deviceIp);
  }

  String get _httpBase => 'http://$_deviceIp:$_httpPort';
  String get _wsUrl => 'ws://$_deviceIp:$_wsPort';

  /// Test connection to ESP32
  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_httpBase/ping'))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
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
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      _isConnected = true;
    } catch (e) {
      _isConnected = false;
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
    _reconnectTimer = Timer(const Duration(seconds: 3), connectWebSocket);
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
      final response = await http
          .get(Uri.parse('$_httpBase/gps'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final gps = GpsData.fromJson(json);
        _gpsStreamController?.add(gps);
        _isConnected = true;
      }
    } catch (_) {
      _isConnected = false;
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
  }

  Future<void> dispose() async {
    await disconnectWebSocket();
    stopHttpPolling();
    await _gpsStreamController?.close();
    await _statusStreamController?.close();
  }
}
