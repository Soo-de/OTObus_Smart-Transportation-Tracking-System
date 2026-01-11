// ===============================================
// KÜTÜPHANE EKLEMELERİ
// ===============================================
#include <ESP8266WiFi.h>
#include <DHT.h>
#include <SoftwareSerial.h>
#include <FirebaseESP8266.h>
#include <time.h>
#include "LedControl.h"
#include "config.h" // WiFi ve Firebase ayarları (config.h.example'dan kopyala)

// ===============================================
// KULLANICI AYARLARI (WIFI & FIREBASE)
// ===============================================
// config.h dosyasından gelen değerler kullanılıyor
const char* WIFI_SSID = WIFI_SSID;
const char* WIFI_PASSWORD = WIFI_PASSWORD;
const char* FIREBASE_HOST_VAL = FIREBASE_HOST;
const char* FIREBASE_AUTH_VAL = FIREBASE_AUTH;

// ===============================================
// PIN TANIMLAMALARI
// ===============================================
const int DIN_PIN = D1;
const int CLK_PIN = D5;
const int CS_PIN  = D8;

#define DHTPIN D2
#define DHTTYPE DHT22
const int mq135Pin = A0;

#define CO2_RX_PIN D6
#define CO2_TX_PIN D7

const int BUTTON_PIN = D4;

// ===============================================
// NESNE TANIMLAMALARI
// ===============================================
LedControl lc = LedControl(DIN_PIN, CLK_PIN, CS_PIN, 1);
DHT dht(DHTPIN, DHTTYPE);
SoftwareSerial co2Serial(CO2_RX_PIN, CO2_TX_PIN);

FirebaseConfig config;
FirebaseAuth auth;
FirebaseData fbdo;

// ===============================================
// SENSOR KOMUTLARI
// ===============================================
byte U_custom = 0b00111110;
byte co2_cmd[9] = {0xFF, 0x01, 0x86, 0x00, 0x00, 0x00, 0x00, 0x00, 0x79};
unsigned char co2_response[9];

// ===============================================
// GLOBAL DEĞİŞKENLER
// ===============================================
float sicaklik = 0.0;
float nem = 0.0;
int havaKalitesi = 0;
int ppm_co2 = 0;

unsigned long lastSensorReadTime = 0;
const long sensorReadInterval = 5000;

unsigned long lastDisplayTime = 0;
const long displayInterval = 200;

const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 3 * 3600;
const int daylightOffset_sec = 0;
bool ntpSynced = false;

volatile bool buttonPressedFlag = false;
unsigned long lastButtonTime = 0;

// ===============================================
// YARDIMCI FONKSİYONLAR
// ===============================================
unsigned long getUnixTimestamp() {
  time_t now = time(nullptr);
  return (unsigned long)now;
}

String getFormattedTime() {
  if (!ntpSynced) return "NTP_Yok";
  time_t now = time(nullptr);
  struct tm* timeinfo = localtime(&now);
  char buffer[32];
  sprintf(buffer, "%04d-%02d-%02d %02d:%02d:%02d",
          timeinfo->tm_year + 1900,
          timeinfo->tm_mon + 1,
          timeinfo->tm_mday,
          timeinfo->tm_hour,
          timeinfo->tm_min,
          timeinfo->tm_sec);
  return String(buffer);
}

byte getCheckSum(unsigned char *packet) {
  byte checksum = 0;
  for (byte i = 1; i < 8; i++) checksum += packet[i];
  return 0xFF - checksum + 1;
}

// ===============================================
// BUTTON INTERRUPT
// ===============================================
ICACHE_RAM_ATTR void handleButtonPress() {
  unsigned long now = millis();
  if (now - lastButtonTime > 250) {
    buttonPressedFlag = true;
    lastButtonTime = now;
  }
}

// ===============================================
// FIREBASE CURRENT DATA (AYNI)
// ===============================================
void sendDataToFirebase() {
  if (!Firebase.ready() || WiFi.status() != WL_CONNECTED) return;

  FirebaseJson currentData;
  currentData.set("co2", ppm_co2);
  currentData.set("humidity", nem);
  currentData.set("temperature", sicaklik);
  currentData.set("voc_quality", havaKalitesi);

  if (ntpSynced) {
    currentData.set("timestamp", getUnixTimestamp());
    currentData.set("readable_time", getFormattedTime());
  } else {
    currentData.set("timestamp", millis());
    currentData.set("readable_time", "NTP_Yok");
  }

  Firebase.setJSON(fbdo, "/home/current_data", currentData);
}

// ===============================================
// FIREBASE HISTORY LOG (AYNI)
// ===============================================
void logDataToHistory() {
  if (!Firebase.ready() || WiFi.status() != WL_CONNECTED) return;

  String logKey;
  if (ntpSynced) {
    time_t now = time(nullptr);
    struct tm* timeinfo = localtime(&now);
    char keyBuffer[30];
    sprintf(keyBuffer, "log_%04d%02d%02d_%02d%02d%02d",
            timeinfo->tm_year + 1900,
            timeinfo->tm_mon + 1,
            timeinfo->tm_mday,
            timeinfo->tm_hour,
            timeinfo->tm_min,
            timeinfo->tm_sec);
    logKey = String(keyBuffer);
  } else {
    logKey = "log_" + String(millis());
  }

  FirebaseJson logData;
  logData.set("co2", ppm_co2);
  logData.set("humidity", nem);
  logData.set("temperature", sicaklik);
  logData.set("voc_quality", havaKalitesi);

  if (ntpSynced) {
    logData.set("timestamp", getUnixTimestamp());
    logData.set("readable_time", getFormattedTime());
  } else {
    logData.set("timestamp", millis());
    logData.set("readable_time", "NTP_Yok");
  }

  Firebase.setJSON(fbdo, "/home/environment_history/" + logKey, logData);
}

// ===============================================
// SENSOR OKUMA
// ===============================================
void readAllSensors() {
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (!isnan(t)) sicaklik = t;
  if (!isnan(h)) nem = h;

  havaKalitesi = analogRead(mq135Pin);

  while (co2Serial.available()) co2Serial.read();
  co2Serial.write(co2_cmd, 9);
  delay(50);
  if (co2Serial.available() >= 9) {
    co2Serial.readBytes(co2_response, 9);
    if (co2_response[8] == getCheckSum(co2_response)) {
      ppm_co2 = (co2_response[2] * 256) + co2_response[3];
    }
  }
}

// ===============================================
// DISPLAY
// ===============================================
void updateDisplay() {
  lc.setDigit(0, 3, 5, false);
  lc.setChar(0, 2, 'A', false);
  lc.setRow(0, 1, U_custom);
  lc.setChar(0, 0, ' ', false);
  lc.setChar(0, 4, ' ', false);
  lc.setDigit(0, 7, 1, false);
  lc.setDigit(0, 6, 0, false);
  lc.setDigit(0, 5, 0, false);
}

// ===============================================
// BUTTON ACTION
// ===============================================
void processButtonAction() {
  if (!Firebase.ready() || WiFi.status() != WL_CONNECTED) return;

  if (Firebase.getBool(fbdo, "/home/door_status")) {
    bool current = fbdo.boolData();
    Firebase.setBool(fbdo, "/home/door_status", !current);
  }
}

// ===============================================
// SETUP
// ===============================================
void setup() {
  Serial.begin(115200);

  lc.shutdown(0, false);
  lc.setIntensity(0, 8);
  lc.clearDisplay(0);

  dht.begin();
  co2Serial.begin(9600);

  pinMode(BUTTON_PIN, INPUT_PULLUP);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  int retry = 0;
  while (time(nullptr) < 100000 && retry < 20) {
    delay(1000);
    retry++;
  }
  if (time(nullptr) > 100000) ntpSynced = true;

  config.host = FIREBASE_HOST_VAL;
  config.signer.tokens.legacy_token = FIREBASE_AUTH_VAL;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  attachInterrupt(digitalPinToInterrupt(BUTTON_PIN), handleButtonPress, FALLING);

  Serial.println("\nSISTEM HAZIR");
}

// ===============================================
// LOOP
// ===============================================
void loop() {
  unsigned long now = millis();

  if (buttonPressedFlag) {
    processButtonAction();
    buttonPressedFlag = false;
  }

  if (now - lastSensorReadTime >= sensorReadInterval) {
    readAllSensors();
    sendDataToFirebase();
    logDataToHistory();
    lastSensorReadTime = now;
  }

  if (now - lastDisplayTime >= displayInterval) {
    updateDisplay();
    lastDisplayTime = now;
  }
}
