import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../models/gps_data.dart';
import '../services/esp32_service.dart';
import '../services/trip_recorder.dart';
import 'settings_screen.dart';
import 'trip_history_screen.dart';
import 'stats_screen.dart';

const Map<ConnectionQuality, String> ConnectionQualityLabel = {
  ConnectionQuality.excellent: 'Excellent connection',
  ConnectionQuality.good: 'Good connection',
  ConnectionQuality.fair: 'Fair connection',
  ConnectionQuality.poor: 'Poor connection',
  ConnectionQuality.disconnected: 'Disconnected',
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final Esp32Service _esp32 = Esp32Service(); // singleton
  final MapController _mapController = MapController();
  final TripRecorder _recorder = TripRecorder();

  GpsData? _currentGps;
  DeviceStatus? _deviceStatus;
  bool _isConnecting = false;
  bool _isFollowing = true;
  final List<_TrackPoint> _trackHistory = [];

  StreamSubscription? _gpsSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _connectionSub;
  Timer? _statusTimer;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initService();
  }

  Future<void> _initService() async {
    await _esp32.init();
    _subscribeStreams();
    _subscribeConnection();
    _connect();
  }

  void _subscribeConnection() {
    _connectionSub = _esp32.connectionStream?.listen((quality) {
      if (!mounted) return;
      if (quality == ConnectionQuality.disconnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Connection lost. Reconnecting...'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (quality == ConnectionQuality.excellent ||
          quality == ConnectionQuality.good) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reconnected successfully'),
            backgroundColor: const Color(0xFF00FF9C),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _subscribeStreams() {
    _gpsSub = _esp32.gpsStream?.listen((gps) {
      if (mounted) {
        setState(() {
          _currentGps = gps;
          if (gps.isValid) {
            final point = _TrackPoint(
              LatLng(gps.latitude, gps.longitude),
              gps.speed,
            );
            _trackHistory.add(point);
            if (_trackHistory.length > 500) _trackHistory.removeAt(0);

            if (_isFollowing) {
              _mapController.move(point, _mapController.camera.zoom);
            }
          }
        });
      }
    });

    _statusSub = _esp32.statusStream?.listen((status) {
      if (mounted) setState(() => _deviceStatus = status);
    });
  }

  Color _connectionQualityColor(ConnectionQuality q) {
    switch (q) {
      case ConnectionQuality.excellent:
        return const Color(0xFF00FF9C);
      case ConnectionQuality.good:
        return const Color(0xFF00E5FF);
      case ConnectionQuality.fair:
        return const Color(0xFFFFD600);
      case ConnectionQuality.poor:
        return Colors.orange;
      case ConnectionQuality.disconnected:
        return Colors.red;
    }
  }

  Future<void> _connect() async {
    setState(() => _isConnecting = true);
    await _esp32.connectWebSocket();
    _esp32.startHttpPolling();

    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final status = await _esp32.getDeviceStatus();
      if (mounted && status != null) setState(() => _deviceStatus = status);
    });

    setState(() => _isConnecting = false);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _gpsSub?.cancel();
    _statusSub?.cancel();
    _connectionSub?.cancel();
    _statusTimer?.cancel();
    _recorder.dispose();
    _esp32.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      body: Stack(
        children: [
          // FULL SCREEN MAP
          _buildMap(),

          // TOP STATUS BAR
          SafeArea(child: _buildTopBar()),

          // BOTTOM INFO PANEL
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomPanel()),

          // FAB cluster
          Positioned(right: 16, bottom: 260, child: _buildFabCluster()),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final center = _currentGps != null && _currentGps!.isValid
        ? LatLng(_currentGps!.latitude, _currentGps!.longitude)
        : const LatLng(8.4822, 124.6472); // Cagayan de Oro default

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && _isFollowing) {
            setState(() => _isFollowing = false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.esp32_gps_tracker',
        ),

        // Speed-colored track polyline
        if (_trackHistory.length >= 2)
          PolylineLayer(polylines: _buildSpeedPolylines()),

        // Accuracy circle
        if (_currentGps != null && _currentGps!.isValid)
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(_currentGps!.latitude, _currentGps!.longitude),
                radius: _currentGps!.accuracy,
                useRadiusInMeter: true,
                color: const Color(0xFF00E5FF).withOpacity(0.1),
                borderColor: const Color(0xFF00E5FF).withOpacity(0.4),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),

        // Marker
        if (_currentGps != null && _currentGps!.isValid)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(_currentGps!.latitude, _currentGps!.longitude),
                width: 60,
                height: 60,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) {
                    final pulse = _pulseController.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 60 * pulse,
                          height: 60 * pulse,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFF00E5FF,
                              ).withOpacity(1 - pulse),
                              width: 2,
                            ),
                          ),
                        ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00E5FF),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Title
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A).withOpacity(0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _esp32.isConnected
                            ? Color.lerp(
                                const Color(0xFF00FF9C),
                                Colors.white,
                                _pulseController.value,
                              )!
                            : Colors.red,
                        boxShadow: _esp32.isConnected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00FF9C,
                                  ).withOpacity(0.7),
                                  blurRadius: 6,
                                ),
                              ]
                            : [],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _esp32.isConnected ? 'CONNECTED' : 'SEARCHING...',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: _esp32.isConnected
                          ? const Color(0xFF00FF9C)
                          : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'ESP32 TRACKER',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      color: Colors.white54,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Settings
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(esp32Service: _esp32),
              ),
            ).then((_) => _connect()),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A).withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A).withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white20,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Coordinates
          if (_currentGps != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'COORDINATES',
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      color: Colors.white38,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentGps!.formattedCoords,
                    style: GoogleFonts.orbitron(
                      fontSize: 15,
                      color: const Color(0xFF00E5FF),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Waiting for GPS signal...',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
            ),

          const SizedBox(height: 14),

          // Stats row
          Row(
            children: [
              _statCard(
                label: 'SPEED',
                value: _currentGps?.formattedSpeed ?? '— km/h',
                icon: Icons.speed,
                color: const Color(0xFF00FF9C),
              ),
              const SizedBox(width: 10),
              _statCard(
                label: 'ALTITUDE',
                value: _currentGps?.formattedAltitude ?? '— m',
                icon: Icons.terrain,
                color: const Color(0xFFFFD600),
              ),
              const SizedBox(width: 10),
              _statCard(
                label: 'SATELLITES',
                value: '${_currentGps?.satellites ?? 0}',
                icon: Icons.satellite_alt,
                color: const Color(0xFFFF6B6B),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Battery + Uptime + Connection Quality row
          if (_deviceStatus != null)
            Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _deviceStatus!.batteryIcon,
                      color: Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Battery ${_deviceStatus!.batteryPercent}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.wifi, color: Colors.white54, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Signal: ${_deviceStatus!.signalStrength}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 100,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white10,
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _deviceStatus!.batteryLevel,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: _deviceStatus!.batteryLevel > 0.3
                                ? const Color(0xFF00FF9C)
                                : Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.monitor_heart, color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      ConnectionQualityLabel[_esp32.connectionQuality]!,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: _connectionQualityColor(_esp32.connectionQuality),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (_deviceStatus!.uptime != null)
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, color: Colors.white38, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Uptime: ${_deviceStatus!.uptime}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2);
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.orbitron(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 7,
                color: Colors.white38,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabCluster() {
    return Column(
      children: [
        // Follow toggle
        _mapFab(
          icon: _isFollowing ? Icons.gps_fixed : Icons.gps_not_fixed,
          color: _isFollowing ? const Color(0xFF00E5FF) : Colors.white54,
          onTap: () {
            setState(() => _isFollowing = !_isFollowing);
            if (_isFollowing && _currentGps != null) {
              _mapController.move(
                LatLng(_currentGps!.latitude, _currentGps!.longitude),
                16,
              );
            }
          },
        ),
        const SizedBox(height: 10),

        // Record trip
        _mapFab(
          icon: _recorder.isRecording ? Icons.stop : Icons.fiber_manual_record,
          color: _recorder.isRecording ? Colors.red : const Color(0xFF00FF9C),
          onTap: () {
            if (_recorder.isRecording) {
              _recorder.stopRecording();
            } else {
              _recorder.startRecording(_esp32.gpsStream);
            }
          },
        ),
        const SizedBox(height: 10),

        // History
        _mapFab(
          icon: Icons.history,
          color: Colors.white54,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
          ),
        ),
        const SizedBox(height: 10),

        // Stats
        _mapFab(
          icon: Icons.bar_chart,
          color: Colors.white54,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StatsScreen()),
          ),
        ),
        const SizedBox(height: 10),

        // Zoom in
        _mapFab(
          icon: Icons.add,
          onTap: () => _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom + 1,
          ),
        ),
        const SizedBox(height: 8),

        // Zoom out
        _mapFab(
          icon: Icons.remove,
          onTap: () => _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom - 1,
          ),
        ),
      ],
    );
  }

  Widget _mapFab({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A).withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: color ?? Colors.white70, size: 20),
      ),
    );
  }

  List<Polyline> _buildSpeedPolylines() {
    if (_trackHistory.length < 2) return [];

    final List<Polyline> segments = [];
    for (int i = 0; i < _trackHistory.length - 1; i++) {
      final speed = _trackHistory[i].speed;
      final color = speed <= 5
          ? const Color(0xFF00E5FF).withOpacity(0.3)
          : speed <= 20
          ? const Color(0xFF00E5FF).withOpacity(0.55)
          : speed <= 40
          ? const Color(0xFFFFD600).withOpacity(0.65)
          : speed <= 60
          ? const Color(0xFFFF8C00).withOpacity(0.75)
          : Colors.red.withOpacity(0.85);
      segments.add(
        Polyline(
          points: [_trackHistory[i].latlng, _trackHistory[i + 1].latlng],
          color: color,
          strokeWidth: 3,
        ),
      );
    }
    return segments;
  }
}

class _TrackPoint {
  final LatLng latlng;
  final double speed;
  const _TrackPoint(this.latlng, this.speed);
}
