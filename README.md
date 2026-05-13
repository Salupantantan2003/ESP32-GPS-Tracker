# 📡 ESP32 GPS Tracker App

Real-time GPS tracking app built with **Flutter** + **ESP32 + NEO-6M GPS module**.  
Works on **Android & Web** with a dark futuristic UI.

---

## 📋 Table of Contents
1. [Hardware Required](#hardware-required)
2. [Circuit Wiring](#circuit-wiring)
3. [ESP32 Firmware Setup](#esp32-firmware-setup)
4. [Flutter App Setup (VS Code)](#flutter-app-setup-vs-code)
5. [Run on Android](#run-on-android)
6. [Push to GitHub](#push-to-github)

---

## 🔩 Hardware Required

| Component          | Qty | Notes                             |
|--------------------|-----|-----------------------------------|
| ESP32 DevKit V1    | 1   | Any 38-pin or 30-pin variant      |
| NEO-6M GPS Module  | 1   | Comes with ceramic patch antenna  |
| Jumper Wires       | 4   | Female-to-Female                  |
| USB Cable          | 1   | For programming ESP32             |
| Power Bank (opt)   | 1   | For portable use                  |
| 10kΩ + 20kΩ res.  | 2   | Optional: battery voltage divider |

---

## ⚡ Circuit Wiring

```
┌─────────────────────────────────────────────────────────────┐
│                    WIRING DIAGRAM                            │
│                                                             │
│  ┌──────────────────┐          ┌─────────────────────┐     │
│  │   ESP32 DevKit   │          │   NEO-6M GPS Module  │     │
│  │                  │          │                      │     │
│  │  3V3  ───────────┼──────────┼── VCC  (RED)         │     │
│  │  GND  ───────────┼──────────┼── GND  (BLACK)       │     │
│  │  GPIO16 (RX2) ───┼──────────┼── TX   (GREEN)       │     │
│  │  GPIO17 (TX2) ───┼──────────┼── RX   (YELLOW)      │     │
│  │                  │          │                      │     │
│  └──────────────────┘          └─────────────────────┘     │
│                                                             │
│  ⚠️  IMPORTANT: Use 3.3V NOT 5V! NEO-6M logic = 3.3V       │
│                                                             │
│  Optional Battery Monitor:                                  │
│  Battery+ ── 10kΩ ──┬── GPIO34                             │
│                     └── 20kΩ ── GND                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Pin Summary Table

| ESP32 Pin     | NEO-6M Pin | Wire Color | Notes                    |
|---------------|-----------|------------|--------------------------|
| 3V3           | VCC       | Red        | 3.3V power only!         |
| GND           | GND       | Black      | Common ground            |
| GPIO16 (RX2)  | TX        | Green      | GPS sends → ESP32 reads  |
| GPIO17 (TX2)  | RX        | Yellow     | ESP32 sends → GPS reads  |

---

## 🔧 ESP32 Firmware Setup

### 1. Install Arduino IDE + ESP32 Support
1. Download [Arduino IDE](https://www.arduino.cc/en/software)
2. Go to **File → Preferences → Additional Board URLs**, add:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
3. **Tools → Board → Board Manager** → search "esp32" → Install

### 2. Install Required Libraries
In Arduino IDE → **Tools → Manage Libraries**, install:
- `TinyGPS++` by Mikal Hart
- `WebSockets` by Markus Sattler (ArduinoWebSockets)
- `ArduinoJson` by Benoit Blanchon

### 3. Configure & Upload
1. Open `firmware/esp32_gps_tracker.ino`
2. Edit WiFi credentials:
   ```cpp
   const char* STA_SSID     = "YOUR_WIFI_NAME";
   const char* STA_PASSWORD = "YOUR_WIFI_PASSWORD";
   ```
3. Select board: **Tools → Board → ESP32 Dev Module**
4. Select port: **Tools → Port → COMX** (Windows) or `/dev/ttyUSB0` (Linux/Mac)
5. Upload speed: **115200**
6. Click **Upload** ⬆️
7. Open Serial Monitor (115200 baud) — you'll see the IP address printed

---

## 📱 Flutter App Setup (VS Code)

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install)
2. Install [VS Code](https://code.visualstudio.com/)
3. In VS Code, install extensions:
   - **Flutter** (by Dart Code)
   - **Dart** (by Dart Code)

### Setup
```bash
# 1. Open project folder in VS Code
cd esp32_gps_tracker_app

# 2. Get dependencies
flutter pub get

# 3. Check setup
flutter doctor
```

### Android Configuration
- Enable **Developer Mode** on your phone:
  **Settings → About Phone → tap "Build Number" 7 times**
- Enable **USB Debugging**:
  **Settings → Developer Options → USB Debugging ON**
- Connect phone via USB

---

## 🚀 Run on Android

```bash
# List connected devices
flutter devices

# Run on connected Android device
flutter run

# Build APK (release)
flutter build apk --release
# APK location: build/app/outputs/flutter-apk/app-release.apk
```

### Run on Web
```bash
flutter run -d chrome
# or
flutter build web
```

---

## 📡 App Configuration

1. Open the app → tap **Settings** (gear icon)
2. Enter your **ESP32's IP address** (shown in Serial Monitor)
3. Tap **Test Connection** to verify
4. Tap **Save & Apply**

The app will auto-connect via **WebSocket** for real-time streaming.  
Falls back to **HTTP polling** every 2 seconds if WebSocket fails.

---

## 🐱 Push to GitHub

### First Time Setup

```bash
# 1. Install Git (if not installed)
# Windows: https://git-scm.com/download/win
# Check: git --version

# 2. Configure Git (one-time)
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# 3. Navigate to project folder
cd esp32_gps_tracker_app

# 4. Initialize git repo
git init

# 5. Create .gitignore (already included)
# 6. Stage all files
git add .

# 7. First commit
git commit -m "Initial commit: ESP32 GPS Tracker Flutter app"
```

### Create GitHub Repository
1. Go to [github.com](https://github.com) → **New repository**
2. Name it: `esp32-gps-tracker`
3. Keep it **Public** or **Private**
4. **DO NOT** check "Initialize with README" (we already have one)
5. Click **Create repository**
6. Copy the repository URL

### Connect & Push

```bash
# Add remote origin (replace with your actual URL)
git remote add origin https://github.com/YOUR_USERNAME/esp32-gps-tracker.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Future Updates
```bash
# After making changes:
git add .
git commit -m "describe your changes here"
git push
```

---

## 📁 Project Structure

```
esp32_gps_tracker_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── models/
│   │   └── gps_data.dart           # GPS & Device data models
│   ├── services/
│   │   └── esp32_service.dart      # ESP32 HTTP + WebSocket service
│   └── screens/
│       ├── splash_screen.dart      # Animated splash
│       ├── home_screen.dart        # Main map screen
│       └── settings_screen.dart   # IP config & circuit ref
├── firmware/
│   └── esp32_gps_tracker.ino      # Arduino firmware for ESP32
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml    # Android permissions
│       └── res/xml/
│           └── network_security_config.xml
├── pubspec.yaml                   # Flutter dependencies
└── README.md                      # This file
```

---

## 🔍 Troubleshooting

| Problem | Solution |
|---------|----------|
| GPS not getting fix | Place antenna near window or outdoors; wait 1-3 min |
| App can't connect | Verify ESP32 & phone are on same WiFi network |
| "Cleartext HTTP" error | Check `network_security_config.xml` is in place |
| Weak GPS signal | Use external antenna or move outdoors |
| Port not found | Install ESP32 USB driver (CP210x or CH340) |

---

## 📄 License
MIT License — free to use, modify, and distribute.
