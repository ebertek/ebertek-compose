// lora-1.ino — Mailbox LoRa receiver / MQTT bridge (home node)
// MIT License
// Copyright 2026 ebertek

#include <Arduino.h>
#include <ArduinoJson.h>
#include <PubSubClient.h>
#include <RadioLib.h>
#include <SPI.h>
#include <WiFi.h>
#include "mbedtls/md.h"
#include "../include/secrets.h"

// ─── User config ─────────────────────────────────────────────────────────────
const char* WIFI_SSID     = WIFI_SSID_VALUE;
const char* WIFI_PASSWORD = WIFI_PASSWORD_VALUE;

const char* MQTT_HOST     = MQTT_HOST_VALUE;
const uint16_t MQTT_PORT  = MQTT_PORT_VALUE;
const char* MQTT_USER     = MQTT_USER_VALUE;
const char* MQTT_PASSWORD = MQTT_PASSWORD_VALUE;
// ─────────────────────────────────────────────────────────────────────────────

const char* TOPIC_EVENT           = "home/mailbox/event";
const char* TOPIC_STATE           = "home/mailbox/state";
const char* TOPIC_BATTERY_VOLTAGE = "home/mailbox/battery_voltage";
const char* TOPIC_BATTERY_PERCENT = "home/mailbox/battery";
const char* TOPIC_COUNTER         = "home/mailbox/counter";
const char* TOPIC_RSSI            = "home/mailbox/rssi";
const char* TOPIC_SNR             = "home/mailbox/snr";
const char* TOPIC_RAW             = "home/mailbox/raw";

// ─── LoRa pins (Heltec WiFi LoRa 32 V3 / V3.2) ───────────────────────────────
#define LORA_NSS  8
#define LORA_SCK  9
#define LORA_MOSI 10
#define LORA_MISO 11
#define LORA_RST  12
#define LORA_BUSY 13
#define LORA_DIO1 14

// ─── LoRa RF config — must match transmitter exactly ─────────────────────────
#define LORA_FREQ_MHZ    868.0
#define LORA_BW_KHZ      125.0
#define LORA_SF          7
#define LORA_CR          5
#define LORA_SYNC_WORD   0x12
#define LORA_TX_POWER_DBM 14   // unused on RX node, required by radio.begin()

// How long to hold the mailbox state ON after a packet is received (ms).
#define MAILBOX_ON_DURATION_MS 15000UL

// MQTT keepalive interval. PubSubClient default is 15 s; set explicitly.
#define MQTT_KEEPALIVE_S 30

SPIClass       spi(FSPI);
SX1262         radio = new Module(LORA_NSS, LORA_DIO1, LORA_RST, LORA_BUSY, spi);
WiFiClient     wifi_client;
PubSubClient   mqtt(wifi_client);

// ISR flag set by the DIO1 interrupt when the SX1262 signals packet-ready.
// volatile so the compiler never optimises away reads in loop().
// IRAM_ATTR places the handler in IRAM so it is safe to call from an ISR
// on ESP32 (flash-cached functions must not be called during flash operations).
volatile bool lora_received_flag = false;

void IRAM_ATTR onLoraReceive() {
    lora_received_flag = true;
}

// Non-zero while the mailbox state is ON; holds the timestamp at which the
// state should revert to OFF.
unsigned long mailbox_on_until_ms = 0;

// ─── Auth ─────────────────────────────────────────────────────────────────────

static const char* LORA_HMAC_SECRET = LORA_HMAC_SECRET_VALUE;

// Must match transmitter exactly.
#define HMAC_TRUNCATED_BYTES 8

// Recompute HMAC using the same canonical form as the transmitter.
// Canonical form: "type|event|boot_id|counter|vbat_str|battery"
String computeHmac(const char* type, const char* event,
                   uint32_t boot_id_val, uint32_t counter,
                   const char* vbat_str, int battery) {
    char message[128];
    snprintf(message, sizeof(message), "%s|%s|%lu|%lu|%s|%d", type, event,
             static_cast<unsigned long>(boot_id_val),
             static_cast<unsigned long>(counter), vbat_str, battery);

    uint8_t digest[32];
    mbedtls_md_context_t ctx;
    const mbedtls_md_info_t* info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);

    mbedtls_md_init(&ctx);
    mbedtls_md_setup(&ctx, info, 1);
    mbedtls_md_hmac_starts(&ctx,
        reinterpret_cast<const unsigned char*>(LORA_HMAC_SECRET),
        strlen(LORA_HMAC_SECRET));
    mbedtls_md_hmac_update(&ctx,
        reinterpret_cast<const unsigned char*>(message),
        strlen(message));
    mbedtls_md_hmac_finish(&ctx, digest);
    mbedtls_md_free(&ctx);

    char hex[HMAC_TRUNCATED_BYTES * 2 + 1];
    for (int i = 0; i < HMAC_TRUNCATED_BYTES; i++) {
        snprintf(hex + i * 2, 3, "%02x", digest[i]);
    }
    return String(hex);
}

// Session tracking for replay protection.
// When boot_id changes, the remote has cold-booted and its counter has reset;
// we reset last_accepted_counter so the first packet of the new session is
// accepted. boot_id is inside the HMAC, so a forged boot_id change is rejected
// before it can affect these state variables.
static uint32_t last_boot_id          = 0;
static uint32_t last_accepted_counter = 0;

// ─── Helpers ─────────────────────────────────────────────────────────────────

// Safe millis() elapsed check that handles the ~49-day rollover correctly.
// Returns true when millis() has passed the target timestamp.
static inline bool millisPassed(unsigned long target_ms) {
    return (long)(millis() - target_ms) >= 0;
}

void connectWiFi() {
    if (WiFi.status() == WL_CONNECTED) return;

    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    Serial.print("WiFi connecting");
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print('.');
    }
    Serial.printf("\nWiFi connected: %s\n", WiFi.localIP().toString().c_str());
}

void connectMqtt() {
    while (!mqtt.connected()) {
        Serial.print("MQTT connecting...");
        bool ok = (strlen(MQTT_USER) > 0)
            ? mqtt.connect("heltec-mailbox-bridge", MQTT_USER, MQTT_PASSWORD)
            : mqtt.connect("heltec-mailbox-bridge");

        if (ok) {
            Serial.println(" connected");
        } else {
            Serial.printf(" failed (rc=%d), retry in 1 s\n", mqtt.state());
            delay(1000);
        }
    }
}

void publishHomeAssistantDiscovery() {
    // All messages are retained so HA picks them up after a broker restart.
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

// Process a received LoRa payload string.
void handlePacket(const String& payload) {
    const float rssi = radio.getRSSI();
    const float snr  = radio.getSNR();

    Serial.printf("RX: %s | RSSI %.1f dBm | SNR %.1f dB\n",
                  payload.c_str(), rssi, snr);

    StaticJsonDocument<320> doc;
    DeserializationError err = deserializeJson(doc, payload);
    if (err) {
        Serial.printf("JSON parse error: %s\n", err.c_str());
        return;
    }

    if (doc["type"] != "mailbox") return;

    // ── Auth: verify HMAC before touching any payload fields ─────────────────
    const char*    type     = doc["type"]    | "";
    const char*    event    = doc["event"]   | "";
    const uint32_t boot_id  = doc["boot_id"] | 0u;
    const uint32_t counter  = doc["counter"] | 0u;
    // Read vbat as the raw JSON string so the HMAC input is byte-for-byte
    // identical to what the transmitter signed — no float round-trip.
    const char*    vbat_str = doc["vbat"]    | "0.00";
    const int      battery  = doc["battery"] | -1;
    const char*    hmac_rx  = doc["hmac"]    | "";

    // Reject packets with no HMAC field at all.
    if (strlen(hmac_rx) == 0) {
        Serial.println("Auth FAIL: missing hmac field, packet dropped");
        return;
    }

    // Recompute expected HMAC and compare. boot_id is inside the HMAC so a
    // forged session-reset attempt is rejected here before anything else.
    String hmac_expected = computeHmac(type, event, boot_id, counter, vbat_str, battery);
    if (!hmac_expected.equals(hmac_rx)) {
        Serial.printf("Auth FAIL: hmac mismatch (got %s, expected %s), packet dropped\n",
                      hmac_rx, hmac_expected.c_str());
        return;
    }

    // Session reset: if boot_id changed the remote has cold-booted and its
    // packet_counter has reset to 0. Reset our window so the new session's
    // first packet (counter=1) is accepted.
    if (boot_id != last_boot_id) {
        Serial.printf("New session detected (boot_id %lu → %lu), resetting counter window\n",
                      static_cast<unsigned long>(last_boot_id),
                      static_cast<unsigned long>(boot_id));
        last_boot_id          = boot_id;
        last_accepted_counter = 0;
    }

    // Replay check: counter must be strictly greater than the last accepted.
    if (counter <= last_accepted_counter) {
        Serial.printf("Auth FAIL: replay detected (counter %lu <= last %lu), packet dropped\n",
                      static_cast<unsigned long>(counter),
                      static_cast<unsigned long>(last_accepted_counter));
        return;
    }
    last_accepted_counter = counter;
    // ─────────────────────────────────────────────────────────────────────────

    Serial.printf("Auth OK (boot_id=%lu counter=%lu)\n",
                  static_cast<unsigned long>(boot_id),
                  static_cast<unsigned long>(counter));

    // Publish raw only after auth passes — don't echo unauthenticated packets.
    mqtt.publish(TOPIC_RAW, payload.c_str(), false);

    char buf[32];

    mqtt.publish(TOPIC_EVENT, event, false);

    mqtt.publish(TOPIC_STATE, "ON", true);
    mailbox_on_until_ms = millis() + MAILBOX_ON_DURATION_MS;

    snprintf(buf, sizeof(buf), "%lu", static_cast<unsigned long>(counter));
    mqtt.publish(TOPIC_COUNTER, buf, true);

    // vbat_str is already the formatted string from the JSON — publish directly.
    mqtt.publish(TOPIC_BATTERY_VOLTAGE, vbat_str, true);

    snprintf(buf, sizeof(buf), "%d", battery);
    mqtt.publish(TOPIC_BATTERY_PERCENT, buf, true);

    snprintf(buf, sizeof(buf), "%.1f", rssi);
    mqtt.publish(TOPIC_RSSI, buf, true);

    snprintf(buf, sizeof(buf), "%.1f", snr);
    mqtt.publish(TOPIC_SNR, buf, true);
}

// ─── Arduino entry points ─────────────────────────────────────────────────────

void setup() {
    Serial.begin(115200);
    delay(500);

    connectWiFi();

    mqtt.setServer(MQTT_HOST, MQTT_PORT);
    mqtt.setKeepAlive(MQTT_KEEPALIVE_S);  // explicit keepalive
    mqtt.setBufferSize(512);
    connectMqtt();
    publishHomeAssistantDiscovery();

    spi.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_NSS);

    int state = radio.begin(
        LORA_FREQ_MHZ, LORA_BW_KHZ, LORA_SF,
        LORA_CR, LORA_SYNC_WORD, LORA_TX_POWER_DBM
    );
    if (state != RADIOLIB_ERR_NONE) {
        Serial.printf("LoRa init failed: %d\n", state);
        while (true) delay(1000);
    }

    // Attach ISR to DIO1: fires when the SX1262 asserts packet-ready.
    // setDio1Action must be called before startReceive().
    radio.setDio1Action(onLoraReceive);

    // Arm async receive — returns immediately; DIO1 ISR sets lora_received_flag
    // when a packet lands in the FIFO.
    state = radio.startReceive();
    if (state != RADIOLIB_ERR_NONE) {
        Serial.printf("startReceive failed: %d\n", state);
        while (true) delay(1000);
    }

    Serial.println("Mailbox LoRa receiver ready (async)");
}

void loop() {
    // Keep WiFi and MQTT alive — runs every iteration without blocking.
    connectWiFi();
    connectMqtt();
    mqtt.loop();

    // FIX: revert mailbox state using rollover-safe elapsed check.
    if (mailbox_on_until_ms > 0 && millisPassed(mailbox_on_until_ms)) {
        mqtt.publish(TOPIC_STATE, "OFF", true);
        mailbox_on_until_ms = 0;
        Serial.println("Mailbox state -> OFF");
    }

    // ISR-flag packet check: lora_received_flag is set by onLoraReceive()
    // the instant DIO1 fires. Clear before readData so a new DIO1 event
    // during/after the read is not lost — it will set the flag again and
    // be picked up on the next loop iteration.
    if (lora_received_flag) {
        lora_received_flag = false;  // clear before readData so a new DIO1 event during/after the read is not lost

        String payload;
        int state = radio.readData(payload);

        if (state == RADIOLIB_ERR_NONE) {
            handlePacket(payload);
        } else {
            Serial.printf("readData error: %d\n", state);
        }

        // Re-arm the receiver for the next packet.
        state = radio.startReceive();
        if (state != RADIOLIB_ERR_NONE) {
            Serial.printf("startReceive re-arm failed: %d\n", state);
        }
    }
}
