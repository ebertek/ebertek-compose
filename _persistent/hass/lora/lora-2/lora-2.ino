// lora-2.ino — Mailbox LoRa transmitter (mailbox node, battery powered)
// MIT License
// Copyright 2026 ebertek

#include <Arduino.h>
#include <ArduinoJson.h>
#include <RadioLib.h>
#include <SPI.h>
#include "driver/rtc_io.h"
#include "mbedtls/md.h"
#include "../include/secrets.h"

// ─── LoRa pins (Heltec WiFi LoRa 32 V3 / V3.2) ───────────────────────────────
#define LORA_NSS  8
#define LORA_SCK  9
#define LORA_MOSI 10
#define LORA_MISO 11
#define LORA_RST  12
#define LORA_BUSY 13
#define LORA_DIO1 14

// ─── GPIO definitions ─────────────────────────────────────────────────────────
// Reed switch: GPIO2, RTC-capable, pulled up internally. HIGH = open (magnet away).
#define REED_PIN        GPIO_NUM_2

// Battery ADC: GPIO1 = ADC1_CH0 = VBAT_Read on the Heltec V3 pin map.
#define BATTERY_ADC_PIN 1

// ADC_Ctrl: GPIO37 gates the battery voltage divider (R13=390K, R14=100K).
// Must be HIGH to enable the divider, LOW otherwise to avoid standby drain.
// Schematic net: ADC_Ctrl → Q3 (S9013) → divider bottom rail.
#define ADC_CTRL_PIN    37

// ─── LoRa RF config — must match receiver exactly ─────────────────────────────
#define LORA_FREQ_MHZ    868.0
#define LORA_BW_KHZ      125.0
#define LORA_SF          7
#define LORA_CR          5
#define LORA_SYNC_WORD   0x12
#define LORA_TX_POWER_DBM 14

// ─── Timing ───────────────────────────────────────────────────────────────────
// Debounce window: reed must read open continuously for this long.
#define DEBOUNCE_MS              750UL

// Delay between TX retry attempt (ms).
#define TX_RETRY_DELAY_MS        500UL

// Light-sleep poll interval while waiting for the mailbox to close (ms).
// The CPU is halted between polls; current drops to ~130 µA on ESP32-S3
// vs ~20 mA fully awake, so an indefinite wait is battery-acceptable.
#define CLOSE_POLL_INTERVAL_MS   500UL

SPIClass spi(FSPI);
SX1262   radio = new Module(LORA_NSS, LORA_DIO1, LORA_RST, LORA_BUSY, spi);

// Both survive deep sleep via RTC slow memory.
// packet_counter is monotonically increasing within a session.
// boot_id is a random token generated once per cold boot (power loss or
// first flash); it lets the receiver distinguish a new session from a replay.
RTC_DATA_ATTR uint32_t packet_counter = 0;
RTC_DATA_ATTR uint32_t boot_id        = 0;

// ─── Session identity ─────────────────────────────────────────────────────────

// Called once per wake. On cold boot (power loss / first flash) boot_id is 0;
// generate a random non-zero value and store it in RTC memory so it persists
// across deep sleep cycles. Deep-sleep wakes leave boot_id unchanged.
void ensureBootId() {
    if (boot_id == 0) {
        boot_id = esp_random();
        if (boot_id == 0) boot_id = 1;  // esp_random() returning 0 is vanishingly
                                         // rare, but guard anyway
    }
}

// ─── Battery reading ──────────────────────────────────────────────────────────

// FIX: enable the ADC_Ctrl gate before sampling, disable after.
// Without this the divider (R13+R14 ≈ 490 KΩ) draws ~8 µA continuously from
// VBAT even during deep sleep, needlessly draining the battery over time.
float readBatteryVoltage() {
    // Enable voltage divider.
    pinMode(ADC_CTRL_PIN, OUTPUT);
    digitalWrite(ADC_CTRL_PIN, HIGH);
    delay(10);  // allow divider output to settle

    analogReadResolution(12);
    analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);

    uint32_t mv_sum = 0;
    for (int i = 0; i < 16; i++) {
        mv_sum += analogReadMilliVolts(BATTERY_ADC_PIN);
        delay(5);
    }

    // Disable voltage divider to stop standby current draw.
    digitalWrite(ADC_CTRL_PIN, LOW);
    pinMode(ADC_CTRL_PIN, INPUT);  // hi-Z, no pull, no drive

    const float adc_mv = static_cast<float>(mv_sum) / 16.0f;

    // Heltec V3/V3.2 schematic: R13=390K (top), R14=100K (bottom).
    // VADC = VBAT * 100/(100+390)  →  VBAT = VADC * 4.9
    return (adc_mv * 4.9f) / 1000.0f;
}

// Linear approximation over the usable LiPo discharge curve (3.3 V–4.2 V).
int batteryPercent(float voltage) {
    if (voltage >= 4.20f) return 100;
    if (voltage <= 3.30f) return 0;
    return static_cast<int>(((voltage - 3.30f) / 0.90f) * 100.0f);
}

// ─── Reed switch ──────────────────────────────────────────────────────────────

bool reedIsOpen() {
    return digitalRead(static_cast<uint8_t>(REED_PIN)) == HIGH;
}

// Returns true only if the reed is still open after DEBOUNCE_MS.
bool debounceOpen() {
    if (!reedIsOpen()) return false;
    delay(DEBOUNCE_MS);
    return reedIsOpen();
}

// Wait indefinitely for the reed to close, using light sleep between polls
// to keep current draw low (~130 µA vs ~20 mA fully awake).
//
// FIX: the previous version had a 5-minute hard timeout that broke out of
// the loop and then entered deep sleep with ext0 level=1 while the reed was
// still HIGH. Because the wakeup trigger is still asserted, the chip wakes
// instantly and enters a perpetual boot loop. Waiting indefinitely is safer:
// the mailbox will close eventually, and light sleep keeps the battery cost
// manageable even if it takes a long time.
void waitForMailboxClosed() {
    while (reedIsOpen()) {
        // Light sleep for one poll interval. The CPU halts; peripherals and
        // RTC remain powered. esp_sleep_enable_timer_wakeup takes microseconds.
        esp_sleep_enable_timer_wakeup(CLOSE_POLL_INTERVAL_MS * 1000ULL);
        esp_light_sleep_start();
        // After waking, loop back and re-check the reed.
    }
    delay(500);  // brief settle after close before arming deep-sleep wakeup
}

// Configure GPIO2 as an RTC input with pullup and arm ext0 wakeup on HIGH.
// ext0 requires an RTC GPIO; GPIO0–GPIO21 qualify on ESP32-S3.
void configureReedWakeup() {
    rtc_gpio_init(REED_PIN);
    rtc_gpio_set_direction(REED_PIN, RTC_GPIO_MODE_INPUT_ONLY);
    rtc_gpio_pullup_en(REED_PIN);
    rtc_gpio_pulldown_dis(REED_PIN);

    // Wake when reed goes HIGH (magnet removed = mailbox opened).
    esp_sleep_enable_ext0_wakeup(REED_PIN, 1);
}

// ─── Auth ─────────────────────────────────────────────────────────────────────

static const char* LORA_HMAC_SECRET = LORA_HMAC_SECRET_VALUE;

// Compute HMAC-SHA256 over all meaningful payload fields and return the first
// HMAC_TRUNCATED_BYTES as a lowercase hex string.
// Canonical form: "type|event|boot_id|counter|vbat_str|battery"
// boot_id scopes the counter to a session, so the receiver can reset its
// replay window when it sees a new boot_id without being vulnerable to an
// attacker forging a boot_id change (boot_id is inside the HMAC).
#define HMAC_TRUNCATED_BYTES 8

String computeHmac(const char* type, const char* event,
                   uint32_t boot_id_val, uint32_t counter,
                   const char* vbat_str, int battery) {
    char message[128];
    snprintf(message, sizeof(message), "%s|%s|%lu|%lu|%s|%d", type, event,
             static_cast<unsigned long>(boot_id_val),
             static_cast<unsigned long>(counter), vbat_str, battery);

    uint8_t digest[32];  // full SHA-256 output
    mbedtls_md_context_t ctx;
    const mbedtls_md_info_t* info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);

    mbedtls_md_init(&ctx);
    mbedtls_md_setup(&ctx, info, /* hmac= */ 1);
    mbedtls_md_hmac_starts(&ctx,
        reinterpret_cast<const unsigned char*>(LORA_HMAC_SECRET),
        strlen(LORA_HMAC_SECRET));
    mbedtls_md_hmac_update(&ctx,
        reinterpret_cast<const unsigned char*>(message),
        strlen(message));
    mbedtls_md_hmac_finish(&ctx, digest);
    mbedtls_md_free(&ctx);

    // Encode first HMAC_TRUNCATED_BYTES as lowercase hex.
    char hex[HMAC_TRUNCATED_BYTES * 2 + 1];
    for (int i = 0; i < HMAC_TRUNCATED_BYTES; i++) {
        snprintf(hex + i * 2, 3, "%02x", digest[i]);
    }
    return String(hex);
}

// ─── LoRa transmit ───────────────────────────────────────────────────────────

// Attempt to transmit payload. Returns RADIOLIB_ERR_NONE on success.
static int transmitOnce(String& payload) {
    int state = radio.transmit(payload);
    if (state == RADIOLIB_ERR_NONE) {
        Serial.println("Packet sent");
    } else {
        Serial.printf("Transmit failed: %d\n", state);
    }
    return state;
}

bool sendMailboxPacket() {
    packet_counter++;

    // Read battery before radio init to keep timing clean.
    const float battery_voltage = readBatteryVoltage();
    const int   battery_percent = batteryPercent(battery_voltage);
    Serial.printf("VBAT: %.2f V (%d%%)\n", battery_voltage, battery_percent);

    spi.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_NSS);

    int state = radio.begin(
        LORA_FREQ_MHZ, LORA_BW_KHZ, LORA_SF,
        LORA_CR, LORA_SYNC_WORD, LORA_TX_POWER_DBM
    );
    if (state != RADIOLIB_ERR_NONE) {
        Serial.printf("LoRa init failed: %d\n", state);
        return false;
    }

    // Build JSON payload.
    const char* type  = "mailbox";
    const char* event = "opened";

    // Format vbat as a string once; use the same value in both the JSON field
    // and the HMAC input so they are guaranteed byte-for-byte identical.
    const String vbat_str = String(battery_voltage, 2);

    JsonDocument doc;
    doc["type"]    = type;
    doc["event"]   = event;
    doc["boot_id"] = boot_id;
    doc["counter"] = packet_counter;
    doc["vbat"]    = vbat_str;
    doc["battery"] = battery_percent;
    doc["hmac"]    = computeHmac(type, event, boot_id, packet_counter, vbat_str.c_str(), battery_percent);

    String payload;
    serializeJson(doc, payload);
    Serial.println(payload);

    // FIX: one automatic retry on failure.
    state = transmitOnce(payload);
    if (state != RADIOLIB_ERR_NONE) {
        Serial.printf("Retrying in %lu ms...\n", TX_RETRY_DELAY_MS);
        delay(TX_RETRY_DELAY_MS);
        state = transmitOnce(payload);
    }

    // Put radio to sleep regardless of TX outcome to save power during the
    // waitForMailboxClosed() phase.
    radio.sleep();

    return (state == RADIOLIB_ERR_NONE);
}

// ─── Arduino entry points ─────────────────────────────────────────────────────

void setup() {
    Serial.begin(115200);
    delay(300);

    // Generate boot_id on first cold boot; leaves it unchanged on deep-sleep wakes.
    ensureBootId();
    Serial.printf("boot_id: %lu\n", static_cast<unsigned long>(boot_id));

    // Normal GPIO mode for reed during the active phase.
    pinMode(static_cast<uint8_t>(REED_PIN), INPUT_PULLUP);

    if (debounceOpen()) {
        sendMailboxPacket();
    } else {
        Serial.println("Ignored wake: debounce failed (spurious wakeup)");
    }

    waitForMailboxClosed();
    configureReedWakeup();

    Serial.println("Sleeping");
    Serial.flush();
    delay(100);
    esp_deep_sleep_start();
}

void loop() {
    // Never reached — device sleeps in setup() and wakes into setup() again.
}
