// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

#ifndef LAMP_ARRAY_H
#define LAMP_ARRAY_H

#include <stdint.h>

// Get Reports
uint16_t GetLampArrayAttributesReport(uint8_t* buffer);
uint16_t GetLampAttributesReport(uint8_t* buffer);

// Set Reports
void SetLampAttributesId(const uint8_t* buffer);
void SetMultipleLamps(const uint8_t* buffer);
void SetLampRange(const uint8_t* buffer);
void SetAutonomousMode(const uint8_t* buffer);

// Maintenance counters surfaced on the CDC status line
uint32_t hid_get_count(void);
uint32_t hid_set_count(void);
void hid_get_count_increment(void);
void hid_set_count_increment(void);

#endif
