import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../models/gps_data.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  final ExportService _export = ExportService();
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  int? _selectedTripId;
  List<GpsData>? _selectedPoints;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final trips = await _db.getAllTrips();
    if (mounted) {
      setState(() {
        _trips = trips;
        _loading = false;
      });
    }
  }

  Future<void> _selectTrip(int tripId) async {
    final points = await _db.getTripPoints(tripId);
    if (mounted) {
      setState(() {
        _selectedTripId = _selectedTripId == tripId ? null : tripId;
        _selectedPoints = _selectedTripId != null ? points : null;
      });
    }
  }

  Future<void> _deleteTrip(int tripId) async {
    await _db.deleteTrip(tripId);
    if (_selectedTripId == tripId) {
      _selectedTripId = null;
      _selectedPoints = null;
    }
    _loadTrips();
  }

  Color _tripColor(int index) {
    const colors = [
      Color(0xFF00E5FF),
      Color(0xFF00FF9C),
      Color(0xFFFFD600),
      Color(0xFFFF6B6B),
      Color(0xFF9C27B0),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        title: Text(
          'TRIP HISTORY',
          style: GoogleFonts.orbitron(
            fontSize: 14,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => _export.exportAllTrips(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.upload, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          : _trips.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text(
                    'No saved trips yet',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white38,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Record a trip from the home screen',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white24,
                      fontSize: 13,
                    ),
                  ),
                ],
              ).animate().fadeIn(),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _trips.length,
              itemBuilder: (ctx, i) {
                final trip = _trips[i];
                final id = trip['id'] as int;
                final name = trip['name'] as String;
                final start = DateTime.fromMillisecondsSinceEpoch(
                  trip['start_time'] as int,
                  isUtc: true,
                ).toLocal();
                final end = trip['end_time'] != null
                    ? DateTime.fromMillisecondsSinceEpoch(
                        trip['end_time'] as int,
                        isUtc: true,
                      ).toLocal()
                    : null;
                final dist = (trip['total_distance'] as num?)?.toDouble() ?? 0;
                final pts = trip['point_count'] as int? ?? 0;
                final maxSpd = (trip['max_speed'] as num?)?.toDouble() ?? 0;
                final color = _tripColor(i);
                final isSelected = _selectedTripId == id;

                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => _selectTrip(id),
                      onLongPress: () => _confirmDelete(id, name),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1B2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? color : Colors.white10,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.spaceGrotesk(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _export.exportTrip(context, id),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.share,
                                      color: color,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _confirmDelete(id, name),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _infoChip(
                                  Icons.calendar_today,
                                  DateFormat('MMM dd, HH:mm').format(start),
                                ),
                                const SizedBox(width: 8),
                                _infoChip(Icons.location_on, '$pts pts'),
                                const SizedBox(width: 8),
                                _infoChip(
                                  Icons.speed,
                                  '${maxSpd.toStringAsFixed(1)} km/h',
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _infoChip(
                                  Icons.timer,
                                  _formatDuration(
                                    end != null
                                        ? end.difference(start)
                                        : DateTime.now().difference(start),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _infoChip(
                                  Icons.satellite_alt,
                                  end != null ? 'Completed' : 'Ongoing',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(),
                    ),
                    if (isSelected && _selectedPoints != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildMiniMap(_selectedPoints!),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white38),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap(List<GpsData> points) {
    if (points.isEmpty) return const SizedBox();
    if (points.length == 1) {
      return FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(points.first.latitude, points.first.longitude),
          initialZoom: 16,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
          ),
        ],
      );
    }

    final latlngs = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    double minLat = latlngs.first.latitude;
    double maxLat = latlngs.first.latitude;
    double minLng = latlngs.first.longitude;
    double maxLng = latlngs.first.longitude;
    for (final p in latlngs) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: latlngs,
              color: const Color(0xFF00E5FF).withOpacity(0.8),
              strokeWidth: 3,
            ),
          ],
        ),
      ],
    );
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Trip',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          'Delete "$name"?',
          style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTrip(id);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
