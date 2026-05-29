/*
 * ESP32 GPS Tracker — WiFi Configuration Template
 *
 * Instructions:
 * 1. Copy this file to "config.h" in the same directory
 * 2. Replace the placeholder values with your actual credentials
 * 3. DO NOT commit config.h to git (it's in .gitignore)
 *
 *   cp firmware/config.example.h firmware/config.h
 */

#ifndef CONFIG_H
#define CONFIG_H

// ─── WiFi Station (STA) Mode ─────────────────────────────────────────────────
// Connect to your home/phone hotspot WiFi network.
// Set USE_STA_MODE to true to connect as a client; false for AP-only mode.
#define USE_STA_MODE true

#define STA_SSID     "YOUR_WIFI_SSID"
#define STA_PASSWORD "YOUR_WIFI_PASSWORD"

// ─── WiFi Access Point (AP) Mode ─────────────────────────────────────────────
// ESP32 creates its own WiFi network. Used when STA fails or USE_STA_MODE=false.
#define AP_SSID     "ESP32-GPS-Tracker"
#define AP_PASSWORD "tracker123"

// ─── API Security (optional) ─────────────────────────────────────────────────
// Set an API key to protect endpoints. Leave empty to disable.
// When set, clients must include header: "X-API-Key: <value>"
#define API_KEY ""

#endif
