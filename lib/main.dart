import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/trip_history_screen.dart';
import 'screens/stats_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait + landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ESP32GPSApp());
}

class ESP32GPSApp extends StatelessWidget {
  const ESP32GPSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 GPS Tracker',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/history': (context) => const TripHistoryScreen(),
        '/stats': (context) => const StatsScreen(),
      },
    );
  }

  ThemeData _buildTheme() {
    const seedColor = Color(0xFF00E5FF); // Cyan accent
    const bgDark = Color(0xFF050B18); // Deep navy
    const surfaceDark = Color(0xFF0D1B2A);
    const cardDark = Color(0xFF112236);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: seedColor,
        secondary: const Color(0xFF00FF9C),
        surface: surfaceDark,
        onPrimary: bgDark,
        onSecondary: bgDark,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: bgDark,
      cardColor: cardDark,
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
    );
  }
}
