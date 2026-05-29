class GpsData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed; // km/h
  final double accuracy;
  final int satellites;
  final DateTime timestamp;
  final bool isValid;

  const GpsData({
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    this.speed = 0.0,
    this.accuracy = 0.0,
    this.satellites = 0,
    required this.timestamp,
    this.isValid = true,
  });

  factory GpsData.fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num).toDouble();
    final lng = (json['lng'] as num).toDouble();
    final coordsValid = lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    final jsonValid = json['valid'] as bool?;
    return GpsData(
      latitude: lat,
      longitude: lng,
      altitude: (json['alt'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      satellites: (json['satellites'] as int?) ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
      isValid: jsonValid ?? coordsValid,
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'alt': altitude,
        'speed': speed,
        'accuracy': accuracy,
        'satellites': satellites,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'valid': isValid,
      };

  GpsData copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    double? speed,
    double? accuracy,
    int? satellites,
    DateTime? timestamp,
    bool? isValid,
  }) {
    return GpsData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      satellites: satellites ?? this.satellites,
      timestamp: timestamp ?? this.timestamp,
      isValid: isValid ?? this.isValid,
    );
  }

  String get formattedCoords =>
      '${latitude.toStringAsFixed(6)}°, ${longitude.toStringAsFixed(6)}°';

  String get formattedSpeed => '${speed.toStringAsFixed(1)} km/h';

  String get formattedAltitude => '${altitude.toStringAsFixed(1)} m';
}

class DeviceStatus {
  final bool isConnected;
  final double batteryLevel; // 0.0 - 1.0
  final String ipAddress;
  final int rssi; // WiFi signal strength
  final String firmwareVersion;
  final DateTime lastSeen;

  const DeviceStatus({
    required this.isConnected,
    required this.batteryLevel,
    required this.ipAddress,
    this.rssi = 0,
    this.firmwareVersion = '1.0.0',
    required this.lastSeen,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      isConnected: (json['connected'] as bool?) ?? false,
      batteryLevel: (json['battery'] as num?)?.toDouble() ?? 0.0,
      ipAddress: json['ip'] as String? ?? '0.0.0.0',
      rssi: (json['rssi'] as int?) ?? 0,
      firmwareVersion: json['firmware'] as String? ?? '1.0.0',
      lastSeen: json['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int)
          : DateTime.now(),
    );
  }

  String get batteryPercent => '${(batteryLevel * 100).round()}%';

  String get signalStrength {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }

  IconData get batteryIcon {
    if (batteryLevel > 0.75) return Icons.battery_full;
    if (batteryLevel > 0.5) return Icons.battery_4_bar;
    if (batteryLevel > 0.25) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }
}
