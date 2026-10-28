// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
//
// ChromaBay ARGB controller: derived from the Microsoft RP2040 LampArray
// sample. The macropad's keyboard matrix, rotary encoder, OLED and speaker
// support have been removed, leaving a lighting-only composite device.
//
// Adapted for the ChromaBay board: lighting-only HID LampArray +
// CDC maintenance channel + onboard heartbeat + crash forensics.

#include <stdio.h>
#include <stdlib.h>

#include "pico/stdlib.h"
#include "pico/bootrom.h"
#include "hardware/gpio.h"
#include "hardware/watchdog.h"
#include "hardware/exception.h"
#include "tusb.h"

#include "usb_descriptors.h"
#include "util.h"
#include "Lighting/Neopixel.h"
#include "Lighting/LampArray.h"
#include "Lighting/LampArrayHidStructs.h"

#define WD_TIMEOUT_MS        2000u
#define STATUS_LED_PERIOD_US 500000u

// Functions
bool lightingTimerCallback(struct repeating_timer* t);

// Crash forensics: watchdog reset counter kept in a scratch register that
// survives warm resets; hard fault traps into a distinctive LED state.
static uint32_t g_boot_count;
static bool g_last_boot_watchdog;

static void __attribute__((noreturn)) hardfault_hook(void) {
    gpio_put(STATUS_LED_PIN, true);
    for (;;) {
        __asm volatile ("nop");
    }
}

static void fault_hook_init(void) {
    g_last_boot_watchdog = watchdog_caused_reboot();
    g_boot_count = watchdog_hw->scratch[0];
    if (g_last_boot_watchdog) {
        g_boot_count++;
    }
    watchdog_hw->scratch[0] = g_boot_count;

    exception_set_exclusive_handler(HARDFAULT_EXCEPTION, hardfault_hook);
    watchdog_enable(WD_TIMEOUT_MS, true);
}

// CDC maintenance channel via stdio polling:
//   '?' -> one-line status report
//   'B' -> reset into BOOTSEL mode for flashing
static void maintenance_poll(void) {
    int c = getchar_timeout_us(0);
    if (c == PICO_ERROR_TIMEOUT) {
        return;
    }
    if (c == '?') {
        printf("STAT mounted=%d get=%lu set=%lu boots=%lu wd=%d\r\n",
               tud_mounted() ? 1 : 0,
               (unsigned long)hid_get_count(),
               (unsigned long)hid_set_count(),
               (unsigned long)g_boot_count,
               g_last_boot_watchdog ? 1 : 0);
    } else if (c == 'B') {
        printf("reboot to BOOTSEL\r\n");
        fflush(stdout);
        reset_usb_boot(0, 0);
    }
}

int main() {
    stdio_init_all();
    fault_hook_init();
    tusb_init();
    NeopixelInit(AUTONOMOUS_LIGHTING_EFFECT, AUTONOMOUS_LIGHTING_COLOR);

    gpio_init(STATUS_LED_PIN);
    gpio_set_dir(STATUS_LED_PIN, GPIO_OUT);
    gpio_put(STATUS_LED_PIN, false);

    struct repeating_timer lightingTimer;
    add_repeating_timer_ms(
        LAMP_UPDATE_RATE_MS,    // Output rate of LampArray HID device
        lightingTimerCallback,  // Callback to update LED state
        NULL,                   // Passed in callback data
        &lightingTimer);        // Timer object

    uint64_t next_led_toggle_us = time_us_64();
    bool status_led = false;

    while (1) {
        watchdog_update();
        tud_task();
        maintenance_poll();

        // Fast blink for the first 3 s after a watchdog reset, then 1 Hz heartbeat
        uint64_t now = time_us_64();
        uint64_t wd_mark_us = g_last_boot_watchdog ? 3000000u : 0u;
        uint64_t led_period = (now < wd_mark_us) ? (STATUS_LED_PERIOD_US / 4) : STATUS_LED_PERIOD_US;
        if (now >= next_led_toggle_us) {
            next_led_toggle_us = now + led_period;
            status_led = !status_led;
            gpio_put(STATUS_LED_PIN, status_led);
        }
    }

    cancel_repeating_timer(&lightingTimer);

    return 0;
}

//--------------------------------------------------------------------
// Timer Callbacks
//--------------------------------------------------------------------

bool lightingTimerCallback(struct repeating_timer* t) {
    NeopixelUpdateEffect();

    return true;
}

//--------------------------------------------------------------------
// TinyUSB HID Callbacks
//--------------------------------------------------------------------

// Invoked when received GET_REPORT control request
// Application must fill buffer report's content and return its length.
// Return zero will cause the stack to STALL request
uint16_t tud_hid_get_report_cb(
        uint8_t instance,
        uint8_t report_id,
        hid_report_type_t report_type,
        uint8_t* buffer,
        uint16_t reqlen) {
    hid_get_count_increment();

    switch (report_id) {
        case REPORT_ID_LIGHTING_LAMP_ARRAY_ATTRIBUTES: {
            return GetLampArrayAttributesReport(buffer);
            break;
        }
        case REPORT_ID_LIGHTING_LAMP_ATTRIBUTES_RESPONSE: {
            return GetLampAttributesReport(buffer);
            break;
        }
        default: {
            break;
        }
    }

    return 0;
}

// Invoked when recieved SET_REPORT control request or
// recieved data on OUT endpoint (Report ID = 0, Type = 0)
void tud_hid_set_report_cb(
        uint8_t instance,
        uint8_t report_id,
        hid_report_type_t report_type,
        uint8_t const* buffer,
        uint16_t bufsize) {
    hid_set_count_increment();

    switch (report_id) {
        case REPORT_ID_LIGHTING_LAMP_ATTRIBUTES_REQUEST: {
            SetLampAttributesId(buffer);
            break;
        }
        case REPORT_ID_LIGHTING_LAMP_MULTI_UPDATE: {
            SetMultipleLamps(buffer);
            break;
        }
        case REPORT_ID_LIGHTING_LAMP_RANGE_UPDATE: {
            SetLampRange(buffer);
            break;
        }
        case REPORT_ID_LIGHTING_LAMP_ARRAY_CONTROL: {
            SetAutonomousMode(buffer);
            break;
        }
        default: {
            break;
        }
    }
}

// Invoked when sent REPORT successfully to host
// Application can use this to send the next report
// Note: For composite reports, report[0] is report ID
void tud_hid_report_complete_cb(uint8_t instance, uint8_t const* report, uint16_t len) {}

//--------------------------------------------------------------------
// TinyUSB Device callbacks
//--------------------------------------------------------------------

// Invoked when line state DTR & RTS are changed via SET_CONTROL_LINE_STATE e.g connected/disconnected
void tud_cdc_line_state_cb(uint8_t itf, bool dtr, bool rts) {}

// Invoked when device is mounted
void tud_mount_cb() {}

// Invoked when device is unmounted
void tud_unmount_cb() {}

// Invoked when USB bus is suspended
void tud_suspend_cb(bool remote_wakeup_en) {}

// Invoked when USB bus is resumed
void tud_resume_cb() {}
