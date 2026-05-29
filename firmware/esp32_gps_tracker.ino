/*
 * ESP32 GPS Tracker Firmware v1.1.0
 * Module: NEO-6M GPS + ESP32 DevKit
 * Features: WiFi AP/STA, WebSocket Server, HTTP REST API, Auto-reconnect
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
const char* STA_SSID     = "YOUR_WIFI_SSID";
const char* STA_PASSWORD = "YOUR_WIFI_PASSWORD";
bool USE_STA_MODE = true;

const char* AP_SSID     = "ESP32-GPS-Tracker";
const char* AP_PASSWORD = "tracker123";

// ─── GPS Config ───────────────────────────────────────────────────────────────
#define GPS_RX_PIN  16
#define GPS_TX_PIN  17
#define GPS_BAUD    9600
#define GPS_TIMEOUT_MS 10000

// ─── Battery ADC ──────────────────────────────────────────────────────────────
#define BATTERY_PIN 34
#define BATTERY_MAX_V 4.2f
#define BATTERY_MIN_V 3.2f

// ─── Objects ──────────────────────────────────────────────────────────────────
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);
WebServer     httpServer(80);
WebSocketsServer wsServer(81);

// ─── State ────────────────────────────────────────────────────────────────────
unsigned long lastBroadcast = 0;
unsigned long lastGpsFix    = 0;
unsigned long lastWiFiCheck = 0;
const unsigned long BROADCAST_INTERVAL = 1000;
const unsigned long WIFI_CHECK_INTERVAL = 30000;
const unsigned long WDT_TIMEOUT = 120000;
int wifiReconnectAttempts = 0;

// ─── Helpers ─────────────────────────────────────────────────────────────────
float getBatteryLevel() {
  int raw = analogRead(BATTERY_PIN);
  float voltage = (raw / 4095.0f) * 3.3f * 2.0f;
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
  data["ip"]         = WiFi.getMode() == WIFI_AP ? WiFi.softAPIP().toString() : WiFi.localIP().toString();
  data["rssi"]       = WiFi.RSSI();
  data["firmware"]   = "1.1.0";
  data["uptime"]     = millis() / 1000;
  data["lastSeen"]   = millis();

  String out;
  serializeJson(doc, out);
  return out;
}

// ─── WiFi Management ─────────────────────────────────────────────────────────
void setupWiFi() {
  if (USE_STA_MODE) {
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    WiFi.persistent(true);
    WiFi.begin(STA_SSID, STA_PASSWORD);
    Serial.print("[WiFi] Connecting to ");
    Serial.print(STA_SSID);

    int retries = 0;
    while (WiFi.status() != WL_CONNECTED && retries < 40) {
      delay(250);
      Serial.print(".");
      retries++;
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\n[WiFi] Connected!");
      Serial.printf("[WiFi] IP: %s | RSSI: %d dBm\n", WiFi.localIP().toString().c_str(), WiFi.RSSI());
      wifiReconnectAttempts = 0;
      return;
    }

    Serial.println("\n[WiFi] STA failed. Falling back to AP mode.");
  }

  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  Serial.printf("[WiFi] AP '%s' started. IP: %s\n", AP_SSID, WiFi.softAPIP().toString().c_str());
}

void checkWiFi() {
  unsigned long now = millis();
  if (now - lastWiFiCheck < WIFI_CHECK_INTERVAL) return;
  lastWiFiCheck = now;

  if (WiFi.getMode() == WIFI_STA && WiFi.status() != WL_CONNECTED) {
    wifiReconnectAttempts++;
    Serial.printf("[WiFi] Disconnected! Reconnect attempt #%d\n", wifiReconnectAttempts);

    WiFi.reconnect();

    int retries = 0;
    while (WiFi.status() != WL_CONNECTED && retries < 20) {
      delay(250);
      retries++;
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.printf("[WiFi] Reconnected! IP: %s\n", WiFi.localIP().toString().c_str());
      wifiReconnectAttempts = 0;
    } else if (wifiReconnectAttempts >= 5) {
      Serial.println("[WiFi] Max retries. Switching to AP mode.");
      WiFi.mode(WIFI_AP);
      WiFi.softAP(AP_SSID, AP_PASSWORD);
      Serial.printf("[WiFi] AP '%s' started. IP: %s\n", AP_SSID, WiFi.softAPIP().toString().c_str());
    }
  }
}

// ─── Watchdog ─────────────────────────────────────────────────────────────────
void checkWatchdog() {
  static unsigned long lastReset = millis();
  unsigned long now = millis();

  if (gps.location.isValid()) {
    lastGpsFix = now;
  }

  bool gpsStuck = (now - lastGpsFix > GPS_TIMEOUT_MS && gps.location.isValid());
  bool totalStuck = (now - lastReset > WDT_TIMEOUT);

  if (gpsStuck) {
    Serial.println("[WDT] GPS fix lost for too long. Reinitializing GPS...");
    gpsSerial.end();
    delay(100);
    gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
    lastGpsFix = now;
  }

  if (totalStuck) {
    Serial.println("[WDT] System watchdog triggered. Restarting...");
    ESP.restart();
  }
}

// ─── HTTP Handlers ────────────────────────────────────────────────────────────
void handlePing() {
  httpServer.send(200, "application/json", "{\"status\":\"ok\",\"firmware\":\"1.1.0\"}");
}

void handleGps() {
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
  doc["ip"]        = WiFi.getMode() == WIFI_AP ? WiFi.softAPIP().toString() : WiFi.localIP().toString();
  doc["rssi"]      = WiFi.RSSI();
  doc["firmware"]  = "1.1.0";
  doc["uptime"]    = millis() / 1000;
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

void handleNotFound() {
  httpServer.send(404, "application/json", "{\"error\":\"not_found\"}");
}

// ─── WebSocket Events ─────────────────────────────────────────────────────────
void onWsEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  if (type == WStype_CONNECTED) {
    Serial.printf("[WS] Client #%u connected\n", num);
    wsServer.sendTXT(num, buildStatusJson());
    wsServer.sendTXT(num, buildGpsJson());
  } else if (type == WStype_DISCONNECTED) {
    Serial.printf("[WS] Client #%u disconnected\n", num);
  } else if (type == WStype_TEXT) {
    String cmd = String((char*)payload);
    cmd.trim();
    if (cmd == "ping") {
      wsServer.sendTXT(num, "{\"type\":\"pong\"}");
    } else if (cmd == "status") {
      wsServer.sendTXT(num, buildStatusJson());
    }
  }
}

// ─── Setup ────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32 GPS Tracker v1.1.0 ===");

  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
  Serial.println("[GPS] Serial started on UART2");

  setupWiFi();

  httpServer.on("/ping",    HTTP_GET,     handlePing);
  httpServer.on("/gps",     HTTP_GET,     handleGps);
  httpServer.on("/status",  HTTP_GET,     handleStatus);
  httpServer.on("/",        HTTP_OPTIONS, handleCors);
  httpServer.onNotFound(handleNotFound);
  httpServer.begin();
  Serial.println("[HTTP] Server started on port 80");

  wsServer.begin();
  wsServer.onEvent(onWsEvent);
  Serial.println("[WS] Server started on port 81");

  Serial.println("[READY] Waiting for GPS fix...");
}

// ─── Loop ─────────────────────────────────────────────────────────────────────
void loop() {
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  httpServer.handleClient();
  wsServer.loop();

  checkWiFi();
  checkWatchdog();

  unsigned long now = millis();
  if (now - lastBroadcast >= BROADCAST_INTERVAL) {
    lastBroadcast = now;
    String gpsMsg    = buildGpsJson();
    String statusMsg = buildStatusJson();
    wsServer.broadcastTXT(gpsMsg);

    static int statusCount = 0;
    if (++statusCount >= 5) {
      wsServer.broadcastTXT(statusMsg);
      statusCount = 0;
      Serial.printf("[SYS] Uptime: %lus | WiFi: %s | Clients: %u\n",
        now / 1000,
        WiFi.getMode() == WIFI_AP ? "AP" : "STA",
        wsServer.connectedClientsCount()
      );
    }

    if (gps.location.isValid()) {
      Serial.printf("[GPS] Lat: %.6f Lng: %.6f Spd: %.1f km/h Sats: %d Alt: %.1f m\n",
        gps.location.lat(), gps.location.lng(),
        gps.speed.kmph(), gps.satellites.value(),
        gps.altitude.meters());
    } else {
      Serial.printf("[GPS] Searching for fix... (%d chars parsed)\n", gps.charsProcessed());
    }
  }
}
