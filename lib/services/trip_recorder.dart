import 'dart:async';
import 'package:flutter/material.dart';
import '../models/gps_data.dart';
import 'database_service.dart';

class TripRecorder extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  StreamSubscription<GpsData>? _gpsSub;

  bool _isRecording = false;
  int _pointCount = 0;
  DateTime? _startTime;

  bool get isRecording => _isRecording;
  int get pointCount => _pointCount;
  DateTime? get startTime => _startTime;
  Duration get elapsed =>
      _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;

  Future<void> startRecording(Stream<GpsData>? gpsStream) async {
    if (_isRecording) return;

    await _db.startTrip();
    _isRecording = true;
    _pointCount = 0;
    _startTime = DateTime.now();
    notifyListeners();

    _gpsSub?.cancel();
    if (gpsStream != null) {
      _gpsSub = gpsStream.listen((gps) {
        if (gps.isValid && _isRecording) {
          _db.saveGpsPoint(gps);
          _pointCount++;
          notifyListeners();
        }
      });
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    await _db.endTrip();
    _gpsSub?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    super.dispose();
  }
}
