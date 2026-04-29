#include <Arduino.h>
#include <ArduinoJson.h>
#include <PubSubClient.h>
#include <RadioLib.h>
#include <SPI.h>
#include <WiFi.h>

const char* WIFI_SSID = "YOUR_WIFI";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

const char* MQTT_HOST = "192.168.1.10";
const uint16_t MQTT_PORT = 1883;
const char* MQTT_USER = "";
const char* MQTT_PASSWORD = "";

const char* TOPIC_EVENT = "home/mailbox/event";
const char* TOPIC_STATE = "home/mailbox/state";
const char* TOPIC_BATTERY_VOLTAGE = "home/mailbox/battery_voltage";
const char* TOPIC_BATTERY_PERCENT = "home/mailbox/battery";
const char* TOPIC_COUNTER = "home/mailbox/counter";
const char* TOPIC_RSSI = "home/mailbox/rssi";
const char* TOPIC_SNR = "home/mailbox/snr";
const char* TOPIC_RAW = "home/mailbox/raw";

#define LORA_NSS 8
#define LORA_SCK 9
#define LORA_MOSI 10
#define LORA_MISO 11
#define LORA_RST 12
#define LORA_BUSY 13
#define LORA_DIO1 14

#define LORA_FREQ_MHZ 868.0
#define LORA_BW_KHZ 125.0
#define LORA_SF 7
#define LORA_CR 5
#define LORA_SYNC_WORD 0x12
#define LORA_TX_POWER_DBM 14

SPIClass spi(FSPI);
SX1262 radio = new Module(LORA_NSS, LORA_DIO1, LORA_RST, LORA_BUSY, spi);

WiFiClient wifi_client;
PubSubClient mqtt(wifi_client);

unsigned long mailbox_on_until_ms = 0;

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }
}

void connectMqtt() {
  while (!mqtt.connected()) {
    bool connected = false;

    if (strlen(MQTT_USER) > 0) {
      connected = mqtt.connect("heltec-mailbox-bridge", MQTT_USER, MQTT_PASSWORD);
    } else {
      connected = mqtt.connect("heltec-mailbox-bridge");
    }

    if (!connected) {
      delay(1000);
    }
  }
}

void publishHomeAssistantDiscovery() {
  mqtt.publish(
      "homeassistant/binary_sensor/mailbox/state/config",
      "{\"name\":\"Mailbox\","
      "\"unique_id\":\"mailbox_state\","
      "\"state_topic\":\"home/mailbox/state\","
      "\"payload_on\":\"ON\","
      "\"payload_off\":\"OFF\","
      "\"device_class\":\"opening\","
      "\"device\":{\"identifiers\":[\"heltec_mailbox\"],\"name\":\"Mailbox LoRa\"}}",
      true
  );

  mqtt.publish(
      "homeassistant/sensor/mailbox/battery_voltage/config",
      "{\"name\":\"Mailbox Battery Voltage\","
      "\"unique_id\":\"mailbox_battery_voltage\","
      "\"state_topic\":\"home/mailbox/battery_voltage\","
      "\"unit_of_measurement\":\"V\","
      "\"device_class\":\"voltage\","
      "\"state_class\":\"measurement\","
      "\"device\":{\"identifiers\":[\"heltec_mailbox\"],\"name\":\"Mailbox LoRa\"}}",
      true
  );

  mqtt.publish(
      "homeassistant/sensor/mailbox/battery/config",
      "{\"name\":\"Mailbox Battery\","
      "\"unique_id\":\"mailbox_battery\","
      "\"state_topic\":\"home/mailbox/battery\","
      "\"unit_of_measurement\":\"%\","
      "\"device_class\":\"battery\","
      "\"state_class\":\"measurement\","
      "\"device\":{\"identifiers\":[\"heltec_mailbox\"],\"name\":\"Mailbox LoRa\"}}",
      true
  );

  mqtt.publish(
      "homeassistant/sensor/mailbox/counter/config",
      "{\"name\":\"Mailbox Packet Counter\","
      "\"unique_id\":\"mailbox_packet_counter\","
      "\"state_topic\":\"home/mailbox/counter\","
      "\"state_class\":\"total_increasing\","
      "\"device\":{\"identifiers\":[\"heltec_mailbox\"],\"name\":\"Mailbox LoRa\"}}",
      true
  );

  mqtt.publish(
      "homeassistant/sensor/mailbox/rssi/config",
      "{\"name\":\"Mailbox LoRa RSSI\","
      "\"unique_id\":\"mailbox_lora_rssi\","
      "\"state_topic\":\"home/mailbox/rssi\","
      "\"unit_of_measurement\":\"dBm\","
      "\"device_class\":\"signal_strength\","
      "\"state_class\":\"measurement\","
      "\"device\":{\"identifiers\":[\"heltec_mailbox\"],\"name\":\"Mailbox LoRa\"}}",
      true
  );

  mqtt.publish(
      "homeassistant/sensor/mailbox/snr/config",
      "{\"name\":\"Mailbox LoRa SNR\","
      "\"unique_id\":\"mailbox_lora_snr\","
      "\"state_topic\":\"home/mailbox/snr\","
      "\"unit_of_measurement\":\"dB\","
      "\"state_class\":\"measurement\","
      "\"device\":{\"identifiers\":[\"heltec_mailbox\"],\"name\":\"Mailbox LoRa\"}}",
      true
  );
}

void setup() {
  Serial.begin(115200);
  delay(500);

  connectWiFi();

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  connectMqtt();
  publishHomeAssistantDiscovery();

  spi.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_NSS);

  int state = radio.begin(
      LORA_FREQ_MHZ,
      LORA_BW_KHZ,
      LORA_SF,
      LORA_CR,
      LORA_SYNC_WORD,
      LORA_TX_POWER_DBM
  );

  if (state != RADIOLIB_ERR_NONE) {
    Serial.printf("LoRa init failed: %d\n", state);
    while (true) {
      delay(1000);
    }
  }

  Serial.println("Mailbox LoRa receiver ready");
}

void loop() {
  connectWiFi();
  connectMqtt();
  mqtt.loop();

  if (mailbox_on_until_ms > 0 && millis() > mailbox_on_until_ms) {
    mqtt.publish(TOPIC_STATE, "OFF", true);
    mailbox_on_until_ms = 0;
  }

  String payload;
  int state = radio.receive(payload);

  if (state == RADIOLIB_ERR_NONE) {
    const float rssi = radio.getRSSI();
    const float snr = radio.getSNR();

    Serial.printf("RX: %s | RSSI %.1f | SNR %.1f\n", payload.c_str(), rssi, snr);
    mqtt.publish(TOPIC_RAW, payload.c_str(), false);

    StaticJsonDocument<192> doc;
    DeserializationError error = deserializeJson(doc, payload);

    if (!error && doc["type"] == "mailbox") {
      const char* event = doc["event"] | "opened";
      const uint32_t counter = doc["counter"] | 0;
      const float vbat = doc["vbat"] | 0.0;
      const int battery = doc["battery"] | -1;

      char buffer[32];

      mqtt.publish(TOPIC_EVENT, event, false);

      mqtt.publish(TOPIC_STATE, "ON", true);
      mailbox_on_until_ms = millis() + 15000;

      snprintf(buffer, sizeof(buffer), "%lu", static_cast<unsigned long>(counter));
      mqtt.publish(TOPIC_COUNTER, buffer, true);

      snprintf(buffer, sizeof(buffer), "%.2f", vbat);
      mqtt.publish(TOPIC_BATTERY_VOLTAGE, buffer, true);

      snprintf(buffer, sizeof(buffer), "%d", battery);
      mqtt.publish(TOPIC_BATTERY_PERCENT, buffer, true);

      snprintf(buffer, sizeof(buffer), "%.1f", rssi);
      mqtt.publish(TOPIC_RSSI, buffer, true);

      snprintf(buffer, sizeof(buffer), "%.1f", snr);
      mqtt.publish(TOPIC_SNR, buffer, true);
    }
  } else if (state != RADIOLIB_ERR_RX_TIMEOUT) {
    Serial.printf("Receive error: %d\n", state);
  }
}
