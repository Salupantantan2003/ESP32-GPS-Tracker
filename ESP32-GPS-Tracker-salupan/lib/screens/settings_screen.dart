import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/esp32_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../utils/validators.dart';

class SettingsScreen extends StatefulWidget {
  final Esp32Service esp32Service;
  const SettingsScreen({super.key, required this.esp32Service});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _db = DatabaseService();
  final ExportService _export = ExportService();
  final AuthService _auth = AuthService();

  late TextEditingController _ipController;
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _testing = false;
  bool? _testResult;
  int _pollInterval = 2;
  bool _pinEnabled = false;
  String? _ipError;
  String? _pinError;


  @override
  void initState() {
    super.initState();
    _ipController =
        TextEditingController(text: widget.esp32Service.deviceIp);
    _loadPinStatus();
  }

   Future<void> _loadPinStatus() async {
    final enabled = await _auth.isPinEnabled();
    if (mounted) setState(() => _pinEnabled = enabled);
  }


  @override
  void dispose() {
    _ipController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final ip = _ipController.text.trim();
    final error = Validators.validateIp(ip);
    if (error != null) {
      setState(() => _ipError = error);
      return;
    }

    setState(() {
      _ipError = null;
      _testing = true;
      _testResult = null;
    });

    await widget.esp32Service.setDeviceIp(ip);
    final ok = await widget.esp32Service.testConnection();

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = ok;
    });
  }

  Future<void> _save() async {
    await widget.esp32Service.setDeviceIp(_ipController.text.trim());
    final ip = _ipController.text.trim();
    setState(() => _ipError = Validators.validateIp(ip));
    if (_ipError != null) return;
    await widget.esp32Service.setDeviceIp(ip);
    if (mounted) Navigator.pop(context);
  }

    Future<void> _setPin() async {
    final pin = _newPinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    setState(() => _pinError = null);

    final pinErr = Validators.validatePin(pin);
    if (pinErr != null) {
      setState(() => _pinError = pinErr);
      return;
    }
    if (pin != confirm) {
      setState(() => _pinError = 'PINs do not match');
      return;
    }

    await _auth.setPin(pin);
    if (mounted) {
      setState(() {
        _pinEnabled = true;
        _pinError = null;
        _newPinController.clear();
        _confirmPinController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PIN security enabled'),
          backgroundColor: const Color(0xFF0D1B2A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _disablePin() async {
    await _auth.disablePin();
    if (mounted) {
      setState(() => _pinEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PIN security disabled'),
          backgroundColor: const Color(0xFF0D1B2A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  void _showPinSetupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'SET PIN',
          style: GoogleFonts.orbitron(
              color: Colors.white, fontSize: 14, letterSpacing: 1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter a 4-6 digit PIN',
              style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: GoogleFonts.orbitron(
                  color: const Color(0xFF00E5FF), fontSize: 20, letterSpacing: 6),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: GoogleFonts.orbitron(
                  color: const Color(0xFF00E5FF), fontSize: 20, letterSpacing: 6),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Confirm PIN',
                hintStyle: GoogleFonts.orbitron(color: Colors.white24, fontSize: 14),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _setPin();
            },
            child: Text('Set PIN',
                style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF00E5FF),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete All Data',
          style: GoogleFonts.orbitron(
              color: Colors.white, fontSize: 14, letterSpacing: 1),
        ),
        content: Text(
          'This will permanently delete all saved trips and GPS points from the database.',
          style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _db.deleteAllTrips();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All data deleted'),
                  backgroundColor: const Color(0xFF0D1B2A),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text('Delete',
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        title: Text(
          'SETTINGS',
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
            child:
                const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device Config
            _sectionTitle('DEVICE CONFIGURATION'),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESP32 IP Address',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ipController,
                    style: GoogleFonts.orbitron(
                        color: const Color(0xFF00E5FF), fontSize: 14),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _ipError = null),
                    decoration: InputDecoration(
                      hintText: '192.168.1.100',
                      hintStyle: GoogleFonts.orbitron(
                          color: Colors.white24, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _ipError != null ? Colors.red : Colors.white10,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _ipError != null ? Colors.red : Colors.white10,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _ipError != null
                              ? Colors.red
                              : const Color(0xFF00E5FF),
                          width: 1.5,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.router,
                        color: _ipError != null ? Colors.red : Colors.white38,
                        size: 18,
                      ),
                      errorText: _ipError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _btn(
                          label: _testing ? 'Testing...' : 'Test Connection',
                          onTap: _testing ? null : _testConnection,
                          outline: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_testResult != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _testResult!
                                ? const Color(0xFF00FF9C).withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _testResult!
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: _testResult!
                                ? const Color(0xFF00FF9C)
                                : Colors.red,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                  if (_testResult == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '✓ ESP32 is reachable!',
                        style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF00FF9C), fontSize: 12),
                      ),
                    ),
                  if (_testResult == false)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '✗ Cannot reach device. Check IP & WiFi.',
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _sectionTitle('POLLING INTERVAL'),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update every $_pollInterval seconds',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white70, fontSize: 13),
                  ),
                  Slider(
                    value: _pollInterval.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: const Color(0xFF00E5FF),
                    inactiveColor: Colors.white10,
                    label: '${_pollInterval}s',
                    onChanged: (v) =>
                        setState(() => _pollInterval = v.round()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _sectionTitle('DATA MANAGEMENT'),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export all trips to CSV',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share GPS trip data with your classmates',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  _btn(
                    label: 'EXPORT ALL TRIPS',
                    onTap: () => _export.exportAllTrips(context),
                    outline: true,
                  ),
                  const SizedBox(height: 10),
                  _btn(
                    label: 'DELETE ALL DATA',
                    onTap: _confirmDeleteAll,
                    outline: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _sectionTitle('SECURITY'),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline,
                          color: _pinEnabled
                              ? const Color(0xFF00FF9C)
                              : Colors.white38,
                          size: 18),
                      const SizedBox(width: 10),
                      Text(
                        _pinEnabled ? 'PIN Lock Active' : 'PIN Lock',
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.white70, fontSize: 13),
                      ),
                      const Spacer(),
                      Switch(
                        value: _pinEnabled,
                        onChanged: (v) {
                          if (v) {
                            _showPinSetupDialog();
                          } else {
                            _disablePin();
                          }
                        },
                        activeColor: const Color(0xFF00E5FF),
                      ),
                    ],
                  ),
                  if (_pinError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _pinError!,
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.red, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Requires a 4-6 digit PIN to access the app',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _sectionTitle('ACCOUNT'),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          color: Colors.white38, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Signed in as',
                              style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white38, fontSize: 11),
                            ),
                            Text(
                              _auth.currentUsername ?? 'Unknown',
                              style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _btn(
                    label: 'LOGOUT',
                    onTap: _logout,
                    outline: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _sectionTitle('CIRCUIT REFERENCE'),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _circuitRow('ESP32 3.3V', 'NEO-6M VCC'),
                  _circuitRow('ESP32 GND', 'NEO-6M GND'),
                  _circuitRow('ESP32 GPIO 16 (RX2)', 'NEO-6M TX'),
                  _circuitRow('ESP32 GPIO 17 (TX2)', 'NEO-6M RX'),
                  const Divider(color: Colors.white10, height: 20),
                  Text(
                    'Baud Rate: 9600 | Update Rate: 1Hz\nPower: 3.3V (DO NOT use 5V!)',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            _btn(label: 'SAVE & APPLY', onTap: _save),
            const SizedBox(height: 20),
          ],
        ).animate().fadeIn(duration: 400.ms),
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

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: child,
      );

  Widget _btn({
    required String label,
    VoidCallback? onTap,
    bool outline = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: outline ? Colors.transparent : const Color(0xFF00E5FF),
            borderRadius: BorderRadius.circular(12),
            border: outline
                ? Border.all(color: const Color(0xFF00E5FF))
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: outline ? const Color(0xFF00E5FF) : const Color(0xFF050B18),
            ),
          ),
        ),
      );

  Widget _circuitRow(String pin1, String pin2) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(pin1,
                  style: GoogleFonts.orbitron(
                      fontSize: 10, color: const Color(0xFF00E5FF))),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, color: Colors.white30, size: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF9C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(pin2,
                  style: GoogleFonts.orbitron(
                      fontSize: 10, color: const Color(0xFF00FF9C))),
            ),
          ],
        ),
      );
}
