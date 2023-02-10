// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

/**
Example demonstrating the use of the AXP192 power management IC.
*/
import gpio
import i2c
import axp192 show *

SDA_PIN := 21
SCL_PIN := 22

main:
  bus := i2c.Bus
      --sda=gpio.Pin SDA_PIN
      --scl=gpio.Pin SCL_PIN
  device := bus.device I2C_ADDRESS

  // Set the LDO3 voltage to 3.3V.
  set_bits device LDO2_3_VOLTAGE_SETTING_REGISTER
      --mask=LDO3_VOLTAGE_MASK
      ldo3_millivolt_to_register 3300

  // Enable LDO3.
  set_bits device POWER_OUTPUT_CONTROL_REGISTER POWER_OUTPUT_LDO3

  // Set the DC1 voltage to 3.3V.
  set_bits device DC_DC1_VOLTAGE_SETTING_REGISTER
      --mask=DC_DC_VOLTAGE_SETTING_MASK
      dc_dc_millivolt_to_register 3300

  // Enable DC1.
  set_bits device POWER_OUTPUT_CONTROL_REGISTER POWER_OUTPUT_DC_DC1
