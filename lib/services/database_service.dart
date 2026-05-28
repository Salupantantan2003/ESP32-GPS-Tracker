import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/gps_data.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;
  int? _activeTripId;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'esp32_gps_tracker.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        total_distance REAL DEFAULT 0,
        max_speed REAL DEFAULT 0,
        avg_speed REAL DEFAULT 0,
        point_count INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE gps_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL DEFAULT 0,
        speed REAL DEFAULT 0,
        accuracy REAL DEFAULT 0,
        satellites INTEGER DEFAULT 0,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_gps_trip ON gps_points(trip_id)');
    await db.execute('CREATE INDEX idx_gps_time ON gps_points(timestamp)');
  }

  bool get hasActiveTrip => _activeTripId != null;
  int? get activeTripId => _activeTripId;

  Future<int> startTrip({String? name}) async {
    final db = await database;
    _activeTripId = await db.insert('trips', {
      'name': name ?? 'Trip ${DateTime.now().toString().substring(0, 16)}',
      'start_time': DateTime.now().millisecondsSinceEpoch,
    });
    return _activeTripId!;
  }

  Future<void> endTrip() async {
    if (_activeTripId == null) return;
    final db = await database;
    await db.update(
      'trips',
      {'end_time': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [_activeTripId],
    );
    await _updateTripStats(_activeTripId!);
    _activeTripId = null;
  }

  Future<void> saveGpsPoint(GpsData data) async {
    if (_activeTripId == null) return;
    final db = await database;
    await db.insert('gps_points', {
      'trip_id': _activeTripId,
      'latitude': data.latitude,
      'longitude': data.longitude,
      'altitude': data.altitude,
      'speed': data.speed,
      'accuracy': data.accuracy,
      'satellites': data.satellites,
      'timestamp': data.timestamp.millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getAllTrips() async {
    final db = await database;
    return await db.query('trips', orderBy: 'start_time DESC');
  }

  Future<Map<String, dynamic>?> getTrip(int tripId) async {
    final db = await database;
    final result =
        await db.query('trips', where: 'id = ?', whereArgs: [tripId]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<GpsData>> getTripPoints(int tripId) async {
    final db = await database;
    final result = await db.query(
      'gps_points',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );
    return result.map((row) => GpsData(
      latitude: row['latitude'] as double,
      longitude: row['longitude'] as double,
      altitude: (row['altitude'] as num?)?.toDouble() ?? 0,
      speed: (row['speed'] as num?)?.toDouble() ?? 0,
      accuracy: (row['accuracy'] as num?)?.toDouble() ?? 0,
      satellites: row['satellites'] as int? ?? 0,
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      isValid: true,
    )).toList();
  }

  Future<void> deleteTrip(int tripId) async {
    final db = await database;
    await db.delete('gps_points',
        where: 'trip_id = ?', whereArgs: [tripId]);
    await db.delete('trips', where: 'id = ?', whereArgs: [tripId]);
  }

  Future<void> deleteAllTrips() async {
    final db = await database;
    await db.delete('gps_points');
    await db.delete('trips');
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final tripCount =
        (Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM trips')) ??
            0);
    final totalPoints =
        (Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM gps_points')) ??
            0);
    final totalDistance =
        (Sqflite.firstDoubleValue(await db.rawQuery(
                'SELECT COALESCE(SUM(total_distance), 0) FROM trips')) ??
            0.0);
    final maxSpeed = (Sqflite.firstDoubleValue(await db.rawQuery(
                'SELECT COALESCE(MAX(max_speed), 0) FROM trips')) ??
            0.0);
    final todayStr = DateTime.now().millisecondsSinceEpoch.toString();
    final todayTrips = (Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM trips WHERE start_time >= ?',
            [DateTime.now()
                .subtract(const Duration(hours: 24))
                .millisecondsSinceEpoch])) ??
        0);

    return {
      'tripCount': tripCount,
      'totalPoints': totalPoints,
      'totalDistance': totalDistance,
      'maxSpeed': maxSpeed,
      'todayTrips': todayTrips,
    };
  }

  Future<String> exportTripToCsv(int tripId) async {
    final trip = await getTrip(tripId);
    final points = await getTripPoints(tripId);
    if (trip == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('Trip: ${trip['name']}');
    buffer.writeln('Date: ${DateTime.fromMillisecondsSinceEpoch(trip['start_time'] as int)}');
    buffer.writeln('');
    buffer.writeln('Latitude,Longitude,Altitude,Speed,Satellites,Timestamp');
    for (final p in points) {
      buffer.writeln(
          '${p.latitude},${p.longitude},${p.altitude},${p.speed},${p.satellites},${p.timestamp.toIso8601String()}');
    }
    return buffer.toString();
  }

  Future<String> exportAllToCsv() async {
    final buffer = StringBuffer();
    final trips = await getAllTrips();
    for (final trip in trips) {
      final points = await getTripPoints(trip['id'] as int);
      buffer.writeln('Trip: ${trip['name']}');
      buffer.writeln(
          'Start: ${DateTime.fromMillisecondsSinceEpoch(trip['start_time'] as int)}');
      buffer.writeln('Latitude,Longitude,Altitude,Speed,Satellites,Timestamp');
      for (final p in points) {
        buffer.writeln(
            '${p.latitude},${p.longitude},${p.altitude},${p.speed},${p.satellites},${p.timestamp.toIso8601String()}');
      }
      buffer.writeln('');
    }
    return buffer.toString();
  }

  Future<void> _updateTripStats(int tripId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt, MAX(speed) as mx, AVG(speed) as avg '
      'FROM gps_points WHERE trip_id = ?',
      [tripId],
    );
    if (result.isEmpty) return;
    final row = result.first;

    final points = await db.query(
      'gps_points',
      columns: ['latitude', 'longitude'],
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );

    double totalDistance = 0;
    for (int i = 1; i < points.length; i++) {
      totalDistance += _calculateDistance(
        points[i - 1]['latitude'] as double,
        points[i - 1]['longitude'] as double,
        points[i]['latitude'] as double,
        points[i]['longitude'] as double,
      );
    }

    await db.update(
      'trips',
      {
        'point_count': row['cnt'],
        'max_speed': row['mx'] ?? 0,
        'avg_speed': row['avg'] ?? 0,
        'total_distance': totalDistance,
      },
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c / 1000;
  }

  double _toRadians(double deg) => deg * math.pi / 180;
}
