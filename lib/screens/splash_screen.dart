import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      body: Stack(
        children: [
          // Animated background grid
          CustomPaint(
            painter: _GridPainter(),
            size: MediaQuery.of(context).size,
          ),

          // Radial glow
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00E5FF).withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ).animate().scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.5, 1.5),
                duration: 3000.ms,
                curve: Curves.easeOut,
              ),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon ring
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5FF),
                      width: 2,
                    ),
                    color: const Color(0xFF00E5FF).withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.gps_fixed,
                    color: Color(0xFF00E5FF),
                    size: 44,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(
                      begin: const Offset(0.3, 0.3),
                      curve: Curves.elasticOut,
                      duration: 900.ms,
                    ),

                const SizedBox(height: 28),

                Text(
                  'ESP32',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    letterSpacing: 8,
                    color: const Color(0xFF00E5FF),
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

                const SizedBox(height: 8),

                Text(
                  'GPS TRACKER',
                  style: GoogleFonts.orbitron(
                    fontSize: 28,
                    letterSpacing: 4,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 500.ms),

                const SizedBox(height: 16),

                Text(
                  'Real-time location monitoring',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: Colors.white38,
                    letterSpacing: 1,
                  ),
                ).animate().fadeIn(delay: 800.ms, duration: 500.ms),

                const SizedBox(height: 60),

                // Loading bar
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white10,
                      color: const Color(0xFF00E5FF),
                      minHeight: 3,
                    ),
                  ),
                ).animate().fadeIn(delay: 1000.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.04)
      ..strokeWidth = 1;

    const step = 40.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
