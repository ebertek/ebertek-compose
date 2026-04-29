#include <Arduino.h>
#include <ArduinoJson.h>
#include <RadioLib.h>
#include <SPI.h>
#include "driver/rtc_io.h"

#define LORA_NSS 8
#define LORA_SCK 9
#define LORA_MOSI 10
#define LORA_MISO 11
#define LORA_RST 12
#define LORA_BUSY 13
#define LORA_DIO1 14

#define REED_PIN GPIO_NUM_2
#define BATTERY_ADC_PIN 1

#define LORA_FREQ_MHZ 868.0
#define LORA_BW_KHZ 125.0
#define LORA_SF 7
#define LORA_CR 5
#define LORA_SYNC_WORD 0x12
#define LORA_TX_POWER_DBM 14

#define DEBOUNCE_MS 750
#define WAIT_FOR_CLOSE_TIMEOUT_MS 300000UL

SPIClass spi(FSPI);
SX1262 radio = new Module(LORA_NSS, LORA_DIO1, LORA_RST, LORA_BUSY, spi);

RTC_DATA_ATTR uint32_t packet_counter = 0;

float readBatteryVoltage() {
  analogReadResolution(12);
  analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);

  uint32_t millivolts_sum = 0;
  for (int i = 0; i < 16; i++) {
    millivolts_sum += analogReadMilliVolts(BATTERY_ADC_PIN);
    delay(5);
  }

  const float adc_mv = static_cast<float>(millivolts_sum) / 16.0f;

  // Heltec V3/V3.2 battery divider: VBAT = VADC * 4.9
  return (adc_mv * 4.9f) / 1000.0f;
}

int batteryPercent(float voltage) {
  if (voltage >= 4.20f) {
    return 100;
  }
  if (voltage <= 3.30f) {
    return 0;
  }

  return static_cast<int>(((voltage - 3.30f) / 0.90f) * 100.0f);
}

bool reedIsOpen() {
  return digitalRead(static_cast<uint8_t>(REED_PIN)) == HIGH;
}

bool debounceOpen() {
  if (!reedIsOpen()) {
    return false;
  }

  delay(DEBOUNCE_MS);
  return reedIsOpen();
}

void configureReedWakeup() {
  rtc_gpio_init(REED_PIN);
  rtc_gpio_set_direction(REED_PIN, RTC_GPIO_MODE_INPUT_ONLY);
  rtc_gpio_pullup_en(REED_PIN);
  rtc_gpio_pulldown_dis(REED_PIN);

  // Wake when mailbox opens / magnet moves away.
  esp_sleep_enable_ext0_wakeup(REED_PIN, 1);
}

void waitForMailboxClosedOrTimeout() {
  const unsigned long start_ms = millis();

  while (reedIsOpen()) {
    if (millis() - start_ms > WAIT_FOR_CLOSE_TIMEOUT_MS) {
      break;
    }

    delay(250);
  }

  delay(500);
}

bool sendMailboxPacket() {
  packet_counter++;

  const float battery_voltage = readBatteryVoltage();
  const int battery_percent = batteryPercent(battery_voltage);

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
    return false;
  }

  StaticJsonDocument<192> doc;
  doc["type"] = "mailbox";
  doc["event"] = "opened";
  doc["counter"] = packet_counter;
  doc["vbat"] = serialized(String(battery_voltage, 2));
  doc["battery"] = battery_percent;

  String payload;
  serializeJson(doc, payload);

  Serial.println(payload);

  state = radio.transmit(payload);
  radio.sleep();

  if (state == RADIOLIB_ERR_NONE) {
    Serial.println("Packet sent");
    return true;
  }

  Serial.printf("Transmit failed: %d\n", state);
  return false;
}

void setup() {
  Serial.begin(115200);
  delay(300);

  pinMode(static_cast<uint8_t>(REED_PIN), INPUT_PULLUP);

  if (debounceOpen()) {
    sendMailboxPacket();
  } else {
    Serial.println("Ignored wake: debounce failed");
  }

  waitForMailboxClosedOrTimeout();
  configureReedWakeup();

  Serial.println("Sleeping");
  delay(100);
  esp_deep_sleep_start();
}

void loop() {
}
