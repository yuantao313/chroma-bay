// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
//
// Product configuration adapted for the ChromaBay controller board:
// a single WS2812 channel instead of the macropad's 12-key matrix.

#ifndef UTIL_H
#define UTIL_H

#include "Lighting/LampArrayHidStructs.h"

// Timing
#define LAMPARRAY_UPDATE_INTERVAL   10000                               // 10 ms update interval, in us
#define LAMP_UPDATE_RATE_MS         LAMPARRAY_UPDATE_INTERVAL / 1000

// ARGB data output: single channel, one PIO state machine
//   ch0 = GP28 x 8 lamps
#define NEOPIXEL_PIO                pio0
#define NEOPIXEL_BITRATE            800000
#define NEOPIXEL_CH0_PIN            28
#define NEOPIXEL_CH0_LEN            8
#define NEOPIXEL_CHANNELS           1
#define NEOPIXEL_COUNT              NEOPIXEL_CH0_LEN

// Data-output polarity: the board's output stage inverts the data line. When
// set, the PIO emits an inverted waveform so the lamp receives normal WS2812
// polarity; clear it for a straight direct-drive output.
#define PHYSICAL_DATA_INVERTED      1

// Row stride of the lamp position grid: row 0 = the GP28 strip
#define NEOPIXEL_PORT_LEN           NEOPIXEL_CH0_LEN

// Onboard status LED (Pico GP25, debug heartbeat)
#define STATUS_LED_PIN              25

// LampArray Attributes
#define LAMPARRAY_LAMP_COUNT        NEOPIXEL_COUNT
#define LAMPARRAY_WIDTH             80000    // 8 lamps, 1 cm spacing
#define LAMPARRAY_HEIGHT            10000    // single row
#define LAMPARRAY_DEPTH             5000     // 5 mm
#define LAMPARRAY_KIND              7        // LampArrayKindChassis

// Lamp positions: strip-major linear grid, 1 cm spacing in x, 1 cm strip pitch in y
#define LAMP_SPACING_X_UM           10000
#define LAMP_SPACING_Y_UM           10000

static inline Position LampPositionAt(uint16_t lampId) {
    Position p = {
        (uint32_t)(lampId % NEOPIXEL_PORT_LEN) * LAMP_SPACING_X_UM + LAMP_SPACING_X_UM / 2,
        (uint32_t)(lampId / NEOPIXEL_PORT_LEN) * LAMP_SPACING_Y_UM + LAMP_SPACING_Y_UM / 2,
        0
    };
    return p;
}

// Misc.
#define AUTONOMOUS_LIGHTING_COLOR   (LampColor){0, 255, 0, 1}
#define AUTONOMOUS_LIGHTING_EFFECT  BLINK

#endif
