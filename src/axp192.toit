// Copyright (C) 2021 Toitware ApS.  All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Constants and helper functions that are useful for driving
  the AXP192 power control chip.  Depending on how the chip
  is integrated in a device the various pins can have
  various effects.
See the m5stack_core2 driver for an example of how to use
  this library.
*/

import gpio
import i2c

// Read-only registers.
POWER_STATUS_REGISTER ::= 0
POWER_STATUS_ACIN_EXISTS ::=            0b1000_0000
POWER_STATUS_ACIN_USABLE ::=            0b0100_0000
POWER_STATUS_VBUS_EXISTS ::=            0b0010_0000
POWER_STATUS_VBUS_USABLE ::=            0b0001_0000
POWER_STATUS_VBUS_HIGHER_THAN_VHOLD ::= 0b0000_1000
POWER_STATUS_POWER_IN_PCB_SHORT ::=     0b0000_0010
POWER_STATUS_ACIN_VBUS_TRIGGER ::=      0b0000_0001

POWER_MODE_CHARGE_STATUS_REGISTER ::= 1
POWER_MODE_AXP192_OVERHEATED ::= 0b1000_0000
POWER_MODE_CHARGING          ::= 0b0100_0000
POWER_MODE_BATTERY_CONNECTED ::= 0b0010_0000
POWER_MODE_BATTERY_ACTIVE    ::= 0b0000_1000

OTG_VBUS_STATUS_REGISTER ::= 4

// 6-9 are the data buffer registers.

// Read-write registers.
EXTEN_AND_DC_DC2_SWITCH_CONTROL_REGISTER ::= 0x10

POWER_OUTPUT_CONTROL_REGISTER ::= 0x12
POWER_OUTPUT_EXTEN  ::= 0b0100_0000
POWER_OUTPUT_DC_DC2 ::= 0b0001_0000
POWER_OUTPUT_LDO3   ::= 0b0000_1000
POWER_OUTPUT_LDO2   ::= 0b0000_0100
POWER_OUTPUT_DC_DC3 ::= 0b0000_0010
POWER_OUTPUT_DC_DC1 ::= 0b0000_0001

DC_DC2_VOLTAGE_SETTING_REGISTER ::= 0x23
DC_DC1_VOLTAGE_SETTING_REGISTER ::= 0x26
DC_DC3_VOLTAGE_SETTING_REGISTER ::= 0x27
DC_DC_VOLTAGE_SETTING_MASK ::= 0b0111_1111

// Note that some voltages can be encoded that are not supported.
dc_dc_millivolt_to_register mv/int -> int:
  if not 700 <= mv < 3900: throw "mV must be in range 700 - 3989"
  return (mv - 700) / 25

DC_DC2_VOLTAGE_SLOPE_PARAMETER_SETTING_REGISTER ::= 0x25

// Low 4 bits are LOD3, high 4 are LDO2.
LDO2_3_VOLTAGE_SETTING_REGISTER ::= 0x28
LDO2_VOLTAGE_MASK ::= 0xf0
LDO3_VOLTAGE_MASK ::= 0x0f

ldo3_millivolt_to_register mv/int -> int:
  if not 1800 <= mv < 3400: throw "mV must be in range 1800 - 3399"
  return (mv - 1800) / 100

ldo2_millivolt_to_register mv/int -> int:
  return (ldo3_millivolt_to_register mv) << 4

VBUS_IPSOUT_PATH_SETTING_REGISTER ::= 0x30
VBUS_IPSOUT_PATH_PIN_CONTROL  := 0b1000_0000
VBUS_IPSOUT_PATH_ALWAYS_OPEN  := 0b0000_0000
VBUS_VHOLD_PRESSURE_LIMITING  := 0b0100_0000
VBUS_VHOLD_UNLIMITED_PRESSURE := 0b0000_0000
VBUS_VHOLD_SETUP_MASK         := 0b0011_1000
VBUS_VHOLD_SETUP_4_0          := 0b0000_0000
VBUS_VHOLD_SETUP_4_1          := 0b0000_1000
VBUS_VHOLD_SETUP_4_2          := 0b0001_0000
VBUS_VHOLD_SETUP_4_3          := 0b0001_1000
VBUS_VHOLD_SETUP_4_4          := 0b0010_0000  // Default 4.4V.
VBUS_VHOLD_SETUP_4_5          := 0b0010_1000
VBUS_VHOLD_SETUP_4_6          := 0b0011_0000
VBUS_VHOLD_SETUP_4_7          := 0b0011_1000
VBUS_CURRENT_LIMIT_CONTROL_ENABLE_ON             ::= 0b0000_0010
VBUS_CURRENT_LIMIT_CONTROL_ENABLE_OFF            ::= 0b0000_0000
VBUS_CURRENT_LIMIT_CONTROL_CURRENT_SELECTION_100 ::= 0b0000_0001
VBUS_CURRENT_LIMIT_CONTROL_CURRENT_SELECTION_500 ::= 0b0000_0000

V_OFF_SHUTDOWN_VOLTAGE_SETTING_REGISTER ::= 0x31

SHUTDOWN_BATTERY_DETECTION_CHGLED_CONTROL_REGISTER ::= 0x32

CHARGE_CONTROL_REGISTER_1 ::= 0x33
CHARGE_INTERNAL_ENABLE_MASK         ::= 0b1000_0000
CHARGE_INTERNAL_ENABLE              ::= 0b1000_0000
CHARGE_INTERNAL_DISABLE             ::= 0b0000_0000
CHARGE_INTERNAL_TARGET_VOLTAGE_MASK ::= 0b0110_0000
CHARGE_INTERNAL_TARGET_VOLTAGE_4_10 ::= 0b0000_0000
CHARGE_INTERNAL_TARGET_VOLTAGE_4_15 ::= 0b0010_0000
CHARGE_INTERNAL_TARGET_VOLTAGE_4_20 ::= 0b0100_0000
CHARGE_INTERNAL_TARGET_VOLTAGE_4_36 ::= 0b0110_0000
CHARGE_INTERNAL_END_CURRENT_MASK    ::= 0b0001_0000
CHARGE_INTERNAL_END_CURRENT_10      ::= 0b0000_0000
CHARGE_INTERNAL_END_CURRENT_15      ::= 0b0001_0000
CHARGE_INTERNAL_CURRENT_MASK        ::= 0b0000_1111

charge_internal_milliamp_to_register ma/int -> int:
  if not 100 <= ma <= 1320: throw "Invalid charging mA"
  return (ma - 100) / 80  // Produces 0-15.

charge_internal_target_millivolts_to_register mv/int -> int:
  if mv == 4360: return 0b0110_0000
  else if mv == 4200: return 0b0100_0000
  else if mv == 4150: return 0b0010_0000
  else if mv == 4100: return 0b0000_0000
  else: throw "Invalid target mV"

charge_external_milliamp_to_register ma/int -> int:
  if not 300 <= ma <= 1000: throw "Invalid internal charging mA"
  return ((ma - 300) / 100) << 3  // Produces 0-7, shifted up 3 bits.

CHARGE_CONTROL_REGISTER_2 ::= 0x34

BACKUP_BATTERY_CHARGE_CONTROL_REGISTER ::= 0x35
BACKUP_BATTERY_CHARGING_ENABLED  ::= 0b1000_0000
BACKUP_BATTERY_CHARGING_DISABLED ::= 0b0000_0000
BACKUP_BATTERY_CHARGING_TARGET_VOLTAGE_MASK     ::= 0b0110_0000
BACKUP_BATTERY_CHARGING_TARGET_3_1              ::= 0b0000_0000
BACKUP_BATTERY_CHARGING_TARGET_3_0              ::= 0b0010_0000  // Or 0b0100_0000 according to data sheet.
BACKUP_BATTERY_CHARGING_TARGET_2_5              ::= 0b0110_0000
BACKUP_BATTERY_CHARGE_CONTROL_REGISTER_RESERVED ::= 0b0001_1100  // Reserved and unchangable in data sheet.
BACKUP_BATTERY_CHARGING_CURRENT_MASK            ::= 0b0000_0011
BACKUP_BATTERY_CHARGING_CURRENT_50              ::= 0b0000_0000  // µA.
BACKUP_BATTERY_CHARGING_CURRENT_100             ::= 0b0000_0001
BACKUP_BATTERY_CHARGING_CURRENT_200             ::= 0b0000_0010
BACKUP_BATTERY_CHARGING_CURRENT_400             ::= 0b0000_0011

PEK_PARAMETER_SETTING_REGISTER ::= 0x36
BOOT_TIME_MASK    ::= 0b1100_0000
BOOT_TIME_128_MS  ::= 0b0000_0000
BOOT_TIME_512_MS  ::= 0b0100_0000  // Default.
BOOT_TIME_1000_MS ::= 0b1000_0000
BOOT_TIME_2000_MS ::= 0b1100_0000
LONG_PRESS_TIME_MASK    ::= 0b0011_0000
LONG_PRESS_TIME_1000_MS ::= 0b0000_0000
LONG_PRESS_TIME_1500_MS ::= 0b0001_0000  // Default.
LONG_PRESS_TIME_2000_MS ::= 0b0010_0000
LONG_PRESS_TIME_2500_MS ::= 0b0011_0000
LONG_PRESS_FUNCTION_MASK      ::= 0b0000_1000
LONG_PRESS_AUTOMATIC_SHUTDOWN ::= 0b0000_1000
LONG_PRESS_TURN_ON            ::= 0b0000_0000  // Default.
PWROK_SIGNAL_DELAY_MASK       ::= 0b0000_0100
PWROK_SIGNAL_32               ::= 0b0000_0000  // 32ms.
PWROK_SIGNAL_64               ::= 0b0000_0100  // 64ms.  Default.
SHUTDOWN_DURATION_MASK        ::= 0b0000_0011
SHUTTOWN_DURATION_4           ::= 0b0000_0000
SHUTTOWN_DURATION_6           ::= 0b0000_0001  // 6s.  Default.
SHUTTOWN_DURATION_8           ::= 0b0000_0010
SHUTTOWN_DURATION_10          ::= 0b0000_0011

CONVERTER_OPERATING_FREQUENCY_SETTING_REGISTER ::= 0x37

BATTERY_CHARGING_LOW_TEMPERATURE_ALARM_SETTING_REGISTER ::= 0x38

BATTERY_CHARGING_HIGH_TEMPERATURE_ALARM_SETTING_REGISTER ::= 0x39

APS_LOW_POWER_LEVEL_1_SETTING_REGISTER ::= 0x3A

APS_LOW_POWER_LEVEL_2_SETTING_REGISTER ::= 0x3B

BATTERY_DISCHARGE_LOW_TEMPERATURE_ALARM_SETTING_REGISTER ::= 0x3C

BATTERY_DISCHARGE_HIGH_TEMPERATURE_ALARM_SETTING_REGISTER ::= 0x3D

DCDC_WORKING_MODE_SETTING_REGISTER ::= 0x80

ADC_ENABLE_SETTING_REGISTER_1 ::= 0x82
ADC_ENABLE_BATTERY_VOLTAGE ::= 0b1000_0000
ADC_ENABLE_BATTERY_CURRENT ::= 0b0100_0000
ADC_ENABLE_ACIN_VOLTAGE    ::= 0b0010_0000
ADC_ENABLE_ACIN_CURRENT    ::= 0b0001_0000
ADC_ENABLE_VBUS_VOLTAGE    ::= 0b0000_1000
ADC_ENABLE_VBUS_CURRENT    ::= 0b0000_0100
ADC_ENABLE_APS_VOLTAGE     ::= 0b0000_0010
ADC_ENABLE_TS_PIN          ::= 0b0000_0001

ADC_ENABLE_SETTING_REGISTER_2 ::= 0x83
ADC_ENABLE_INTERNAL_TEMPERATURE ::= 0b1000_0000
ADC_ENABLE_GPIO_0               ::= 0b0000_1000
ADC_ENABLE_GPIO_1               ::= 0b0000_0100
ADC_ENABLE_GPIO_2               ::= 0b0000_0010
ADC_ENABLE_GPIO_3               ::= 0b0000_0001

ADC_SAMPLING_RATE_SETTING_TS_PIN_CONTROL_REGISTER ::= 0x85

GPIO_3_0_INPUT_RANGE_SETTING_REGISTER ::= 0x85

TIMER_CONTROL_REGISTER ::= 0x8A

VBUS_MONITORING_SETTING_REGISTER ::= 0x8B

OVER_TEMPERATURE_SHUTDOWN_CONTROL_REGISTER ::= 0x8F

GPIO_0_CONTROL_REGISTER ::= 0x90
GPIO_1_CONTROL_REGISTER ::= 0x92
GPIO_2_CONTROL_REGISTER ::= 0x93
GPIO_CONTROL_MASK                            ::= 0b111
GPIO_CONTROL_NMOS_OPEN_DRAIN_OUTPUT          ::= 0b000
GPIO_CONTROL_UNIVERSAL_INPUT_FUNCTION        ::= 0b001
// Only for GPIO 0.
GPIO_CONTROL_LOW_NOISE_LDO                   ::= 0b010
// Only for GPIO 1 and 2.
GPIO_CONTROL_PWM_2_OUTPUT_HIGH_LEVEL_IS_VINT ::= 0b010  // Marked "do not can be less than 100k pull-down-resistor" in data sheet.
GPIO_CONTROL_KEEP                            ::= 0b011
GPIO_CONTROL_ADC_ENTER                       ::= 0b100
GPIO_CONTROL_LOW_OUTPUT                      ::= 0b101
GPIO_CONTROL_FLOATING                        ::= 0b110  // Or 0b111.

GPIO_0_LDO_MODE_OUTPUT_VOLTAGE_SETTING_REGISTER ::= 0x91
LDO_OUTPUT_VOLTAGE_MASK ::= 0xF0

ldo_output_voltage_to_register mv/int -> int:
  if not 1800 <= mv <= 3300: throw "LDO output voltage must be between 1800mV and 3300mV"
  return ((mv - 1800) / 100) << 4

GPIO_2_0_SIGNAL_STATUS_REGISTER ::= 0x94
GPIO_2_READ_INPUT    ::= 0b0100_0000
GPIO_1_READ_INPUT    ::= 0b0010_0000
GPIO_0_READ_INPUT    ::= 0b0001_0000
// 0 = low, 1 = floating.
GPIO_2_WRITE_OUTPUT  ::= 0b0000_0100
GPIO_1_WRITE_OUTPUT  ::= 0b0000_0010
GPIO_0_WRITE_OUTPUT  ::= 0b0000_0001

GPIO_4_3_FUNCTION_CONTROL_REGISTER ::= 0x95
GPIO_4_3_FEATURES_MASK      ::= 0b1000_0000
GPIO_4_3_FEATURES_ENABLE    ::= 0b1000_0000
GPIO_4_3_FEATURES_DISABLE   ::= 0b0000_0000
GPIO_4_FUNCTION_MASK        ::= 0b0000_1100
GPIO_3_FUNCTION_MASK        ::= 0b0000_0011
GPIO_3_EXTERNAL_CHARGING_CONTROL   ::= 0b00
GPIO_3_NMOS_OPEN_DRAIN_OUTPUT      ::= 0b01
GPIO_3_UNIVERSAL_INPUT_PORT        ::= 0b10
GPIO_3_ADC_INPUT                   ::= 0b11
GPIO_4_EXTERNAL_CHARGING_CONTROL ::= 0b0000
GPIO_4_NMOS_OPEN_DRAIN_OUTPUT    ::= 0b0100
GPIO_4_UNIVERSAL_INPUT_PORT      ::= 0b1000

GPIO_4_3_SIGNAL_STATUS_REGISTER ::= 0x96
GPIO_4_READ_INPUT   ::= 0b0010_0000
GPIO_3_READ_INPUT   ::= 0b0001_0000
GPIO_4_WRITE_OUTPUT ::= 0b0000_0010
GPIO_3_WRITE_OUTPUT ::= 0b0000_0001

/// Set the given bits to 1 in the register.  If the mask is given
///   then the bits in the mask are first cleared.
set_bits device register/int bits/int --mask=bits:
  reg := (device.registers.read_bytes register 1)
  reg[0] = (reg[0] & (mask ^ 0xff)) | bits
  device.registers.write_bytes register reg

/// Clear the given bits in the register. 
clear_bits device register bits:
  reg := (device.registers.read_bytes register 1)
  reg[0] &= ~bits
  device.registers.write_bytes register reg

REGISTER_TO_NAME ::= {
  0x00: "Power status",
  0x01: "Power mode charge status",
  0x04: "OTG VBUS status",
  0x10: "EXTEN and DC_DC2 switch control",
  0x12: "Power output control",
  0x23: "DC_DC2 voltage setting",
  0x26: "DC_DC1 voltage setting",
  0x27: "DC_DC3 voltage setting",
  0x25: "DC_DC2 voltage slope parameter setting",
  0x28: "LDO2/3 voltage setting",
  0x30: "VBUS IPSOUT path setting",
  0x31: "V_OFF shutdown voltage setting",
  0x32: "Shutdown battery detection CHGLED control",
  0x33: "Charge control 1",
  0x34: "Charge control 2",
  0x35: "Backup battery charge control",
  0x36: "PEK parameter setting",
  0x82: "ADC enable setting 1",
  0x83: "ADC enable setting 2",
  0x90: "GPIO 0 control",
  0x92: "GPIO 1 control",
  0x93: "GPIO 2 control",
  0x91: "GPIO 0 LDO mode output voltage settings",
  0x94: "GPIO 2:0 signal status",
  0x95: "GPIO 4:3 functions control",
  0x96: "GPIO 4:3 signal status",
}
