import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';

class ExportService {
  final DatabaseService _db = DatabaseService();

  Future<void> exportAllTrips(BuildContext context) async {
    final csv = await _db.exportAllToCsv();
    if (csv.isEmpty) {
      _showSnack(context, 'No trips to export');
      return;
    }

    await _saveAndShare(context, csv, 'esp32_gps_all_trips.csv');
  }

  Future<void> exportTrip(BuildContext context, int tripId) async {
    final trip = await _db.getTrip(tripId);
    final csv = await _db.exportTripToCsv(tripId);
    if (csv.isEmpty || trip == null) {
      _showSnack(context, 'Trip not found');
      return;
    }

    final name = (trip['name'] as String)
        .replaceAll(' ', '_')
        .toLowerCase();
    await _saveAndShare(context, csv, '${name}_export.csv');
  }

  Future<void> _saveAndShare(
      BuildContext context, String content, String filename) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(content);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'ESP32 GPS Tracker - Trip Data',
        text: 'GPS trip data exported from ESP32 GPS Tracker',
      );
    } catch (e) {
      _showSnack(context, 'Export failed: $e');
    }
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF0D1B2A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
