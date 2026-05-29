/*
 * ESP32 GPS Tracker Firmware
 * Module: NEO-6M GPS + ESP32 DevKit
 * Features: WiFi AP/STA, WebSocket Server, HTTP REST API
 *
 * Required Libraries (install via Arduino Library Manager):
 *   - TinyGPS++ by Mikal Hart
 *   - ArduinoWebSockets by Gil Maimon
 *   - ArduinoJson by Benoit Blanchon
 *
 * Board: ESP32 Dev Module
 * Upload Speed: 115200
 */

#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>
#include <ArduinoJson.h>
#include <TinyGPSPlus.h>
#include <HardwareSerial.h>

// ─── WiFi Config ──────────────────────────────────────────────────────────────
// Option A: Connect to existing WiFi (STA mode) - change these:
const char* STA_SSID     = "YOUR_WIFI_SSID";
const char* STA_PASSWORD = "YOUR_WIFI_PASSWORD";
bool USE_STA_MODE = true;  // set false to use AP mode

// Option B: Create own hotspot (AP mode)
const char* AP_SSID     = "ESP32-GPS-Tracker";
const char* AP_PASSWORD = "tracker123";

// ─── GPS Config ───────────────────────────────────────────────────────────────
#define GPS_RX_PIN  16   // ESP32 GPIO16 ← NEO-6M TX
#define GPS_TX_PIN  17   // ESP32 GPIO17 → NEO-6M RX
#define GPS_BAUD    9600

// ─── Battery ADC (optional voltage divider on GPIO34) ─────────────────────────
#define BATTERY_PIN 34
#define BATTERY_MAX_V 4.2f
#define BATTERY_MIN_V 3.2f

// ─── Objects ──────────────────────────────────────────────────────────────────
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);  // UART2
WebServer     httpServer(80);
WebSocketsServer wsServer(81);

// ─── State ────────────────────────────────────────────────────────────────────
unsigned long lastBroadcast = 0;
const unsigned long BROADCAST_INTERVAL = 1000; // ms

// ─── Helpers ─────────────────────────────────────────────────────────────────
float getBatteryLevel() {
  int raw = analogRead(BATTERY_PIN);
  float voltage = (raw / 4095.0f) * 3.3f * 2.0f;  // x2 for voltage divider
  float level = (voltage - BATTERY_MIN_V) / (BATTERY_MAX_V - BATTERY_MIN_V);
  return constrain(level, 0.0f, 1.0f);
}

String buildGpsJson() {
  StaticJsonDocument<256> doc;
  doc["type"] = "gps";
  JsonObject data = doc.createNestedObject("data");
  data["lat"]       = gps.location.isValid() ? gps.location.lat() : 0.0;
  data["lng"]       = gps.location.isValid() ? gps.location.lng() : 0.0;
  data["alt"]       = gps.altitude.isValid()  ? gps.altitude.meters()   : 0.0;
  data["speed"]     = gps.speed.isValid()     ? gps.speed.kmph()        : 0.0;
  data["accuracy"]  = gps.hdop.isValid()      ? gps.hdop.hdop() * 5.0  : 99.0;
  data["satellites"]= gps.satellites.isValid()? (int)gps.satellites.value() : 0;
  data["valid"]     = gps.location.isValid();
  data["timestamp"] = millis();

  String out;
  serializeJson(doc, out);
  return out;
}

String buildStatusJson() {
  StaticJsonDocument<256> doc;
  doc["type"] = "status";
  JsonObject data = doc.createNestedObject("data");
  data["connected"]  = true;
  data["battery"]    = getBatteryLevel();
  data["ip"]         = WiFi.localIP().toString();
  data["rssi"]       = WiFi.RSSI();
  data["firmware"]   = "1.0.0";
  data["lastSeen"]   = millis();

  String out;
  serializeJson(doc, out);
  return out;
}

// ─── HTTP Handlers ────────────────────────────────────────────────────────────
void handlePing() {
  httpServer.send(200, "application/json", "{\"status\":\"ok\"}");
}

void handleGps() {
  // Return only the data object (not wrapped)
  StaticJsonDocument<200> doc;
  doc["lat"]        = gps.location.isValid() ? gps.location.lat()       : 0.0;
  doc["lng"]        = gps.location.isValid() ? gps.location.lng()       : 0.0;
  doc["alt"]        = gps.altitude.isValid() ? gps.altitude.meters()    : 0.0;
  doc["speed"]      = gps.speed.isValid()    ? gps.speed.kmph()         : 0.0;
  doc["accuracy"]   = gps.hdop.isValid()     ? gps.hdop.hdop() * 5.0   : 99.0;
  doc["satellites"] = gps.satellites.isValid()? (int)gps.satellites.value() : 0;
  doc["valid"]      = gps.location.isValid();
  doc["timestamp"]  = millis();

  String response;
  serializeJson(doc, response);
  httpServer.send(200, "application/json", response);
}

void handleStatus() {
  StaticJsonDocument<200> doc;
  doc["connected"] = true;
  doc["battery"]   = getBatteryLevel();
  doc["ip"]        = WiFi.localIP().toString();
  doc["rssi"]      = WiFi.RSSI();
  doc["firmware"]  = "1.0.0";
  doc["lastSeen"]  = millis();

  String response;
  serializeJson(doc, response);
  httpServer.send(200, "application/json", response);
}

void handleCors() {
  httpServer.sendHeader("Access-Control-Allow-Origin", "*");
  httpServer.sendHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  httpServer.sendHeader("Access-Control-Allow-Headers", "Content-Type");
  httpServer.send(204);
}

// ─── WebSocket Events ─────────────────────────────────────────────────────────
void onWsEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  if (type == WStype_CONNECTED) {
    Serial.printf("[WS] Client #%u connected\n", num);
    // Send immediate status on connect
    wsServer.sendTXT(num, buildStatusJson());
    wsServer.sendTXT(num, buildGpsJson());
  } else if (type == WStype_DISCONNECTED) {
    Serial.printf("[WS] Client #%u disconnected\n", num);
  }
}

// ─── Setup ────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32 GPS Tracker ===");

  // GPS Serial
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
  Serial.println("[GPS] Serial started on UART2");

  // WiFi
  if (USE_STA_MODE) {
    WiFi.mode(WIFI_STA);
    WiFi.begin(STA_SSID, STA_PASSWORD);
    Serial.print("[WiFi] Connecting to ");
    Serial.print(STA_SSID);
    int retries = 0;
    while (WiFi.status() != WL_CONNECTED && retries < 20) {
      delay(500);
      Serial.print(".");
      retries++;
    }
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\n[WiFi] Connected!");
      Serial.print("[WiFi] IP: ");
      Serial.println(WiFi.localIP());
    } else {
      Serial.println("\n[WiFi] Failed. Falling back to AP mode.");
      USE_STA_MODE = false;
    }
  }

  if (!USE_STA_MODE) {
    WiFi.mode(WIFI_AP);
    WiFi.softAP(AP_SSID, AP_PASSWORD);
    Serial.print("[WiFi] AP started. IP: ");
    Serial.println(WiFi.softAPIP());
  }

  // HTTP routes
  httpServer.on("/ping",    HTTP_GET,     handlePing);
  httpServer.on("/gps",     HTTP_GET,     handleGps);
  httpServer.on("/status",  HTTP_GET,     handleStatus);
  httpServer.on("/",        HTTP_OPTIONS, handleCors);
  httpServer.begin();
  Serial.println("[HTTP] Server started on port 80");

  // WebSocket
  wsServer.begin();
  wsServer.onEvent(onWsEvent);
  Serial.println("[WS] Server started on port 81");

  Serial.println("[READY] Waiting for GPS fix...");
}

// ─── Loop ─────────────────────────────────────────────────────────────────────
void loop() {
  // Feed GPS data
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  // Handle HTTP
  httpServer.handleClient();

  // Handle WebSocket
  wsServer.loop();

  // Broadcast GPS every second
  unsigned long now = millis();
  if (now - lastBroadcast >= BROADCAST_INTERVAL) {
    lastBroadcast = now;
    String gpsMsg    = buildGpsJson();
    String statusMsg = buildStatusJson();
    wsServer.broadcastTXT(gpsMsg);

    // Status every 5 seconds
    static int statusCount = 0;
    if (++statusCount >= 5) {
      wsServer.broadcastTXT(statusMsg);
      statusCount = 0;
    }

    // Debug
    if (gps.location.isValid()) {
      Serial.printf("[GPS] Lat: %.6f Lng: %.6f Spd: %.1f km/h Sats: %d\n",
        gps.location.lat(), gps.location.lng(),
        gps.speed.kmph(), gps.satellites.value());
    } else {
      Serial.println("[GPS] Searching for fix...");
    }
  }
}
