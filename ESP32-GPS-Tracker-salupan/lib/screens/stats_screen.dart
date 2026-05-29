import 'package:flutter/material.dart';
import 'package:flutter_animate.dart/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../services/database_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final DatabaseService _db = DatabaseService();
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _db.getStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        title: Text(
          'STATISTICS',
          style: GoogleFonts.orbitron(
              fontSize: 14, letterSpacing: 3, fontWeight: FontWeight.w600),
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
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: Colors.white),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: const Color(0xFF00E5FF),
              backgroundColor: const Color(0xFF0D1B2A),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('OVERVIEW'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _statCard(
                                Icons.route,
                                'Trips',
                                '${_stats['tripCount']}',
                                const Color(0xFF00E5FF))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _statCard(
                                Icons.satellite_alt,
                                'GPS Points',
                                '${_stats['totalPoints']}',
                                const Color(0xFF00FF9C))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: _statCard(
                                Icons.map,
                                'Total Distance',
                                '${(_stats['totalDistance'] as num).toStringAsFixed(2)} km',
                                const Color(0xFFFFD600))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _statCard(
                                Icons.speed,
                                'Max Speed',
                                '${(_stats['maxSpeed'] as num).toStringAsFixed(1)} km/h',
                                const Color(0xFFFF6B6B))),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _sectionTitle('TODAY'),
                    const SizedBox(height: 12),
                    _todayCard(),

                    const SizedBox(height: 24),
                    _sectionTitle('RECENT ACTIVITY'),
                    const SizedBox(height: 12),
                    _recentTripsCard(),

                    const SizedBox(height: 24),
                    _sectionTitle('STORAGE'),
                    const SizedBox(height: 12),
                    _storageCard(),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.orbitron(
          fontSize: 10,
          letterSpacing: 3,
          color: const Color(0xFF00E5FF),
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 8,
              color: Colors.white38,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayCard() {
    final today = _stats['todayTrips'] ?? 0;
    final total = _stats['tripCount'] as int? ?? 1;
    final pct = total > 0 ? today / total : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 36,
            percent: pct.clamp(0.0, 1.0),
            progressColor: const Color(0xFF00E5FF),
            backgroundColor: Colors.white10,
            center: Text(
              '$today',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Trips',
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$today out of $total total trips recorded today',
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentTripsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _activityRow('Trips Recorded', '${_stats['tripCount']}'),
          const Divider(color: Colors.white10, height: 20),
          _activityRow('Total GPS Points', '${_stats['totalPoints']}'),
          const Divider(color: Colors.white10, height: 20),
          _activityRow('Avg Points/Trip',
              '${_stats['tripCount'] > 0 ? (_stats['totalPoints'] / _stats['tripCount']).round() : 0}'),
        ],
      ),
    );
  }

  Widget _activityRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 13),
        ),
        Text(
          value,
          style: GoogleFonts.orbitron(
            color: const Color(0xFF00E5FF),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _storageCard() {
    final pts = _stats['totalPoints'] as int? ?? 0;
    final estimatedBytes = pts * 64;
    final mb = estimatedBytes / (1024 * 1024);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(Icons.storage, color: Colors.white38, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Database Size',
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '~${mb.toStringAsFixed(2)} MB estimated',
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
