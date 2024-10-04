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
POWER-STATUS-REGISTER ::= 0
POWER-STATUS-ACIN-EXISTS ::=            0b1000_0000
POWER-STATUS-ACIN-USABLE ::=            0b0100_0000
POWER-STATUS-VBUS-EXISTS ::=            0b0010_0000
POWER-STATUS-VBUS-USABLE ::=            0b0001_0000
POWER-STATUS-VBUS-HIGHER-THAN-VHOLD ::= 0b0000_1000
POWER-STATUS-POWER-IN-PCB-SHORT ::=     0b0000_0010
POWER-STATUS-ACIN-VBUS-TRIGGER ::=      0b0000_0001

POWER-MODE-CHARGE-STATUS-REGISTER ::= 1
POWER-MODE-AXP192-OVERHEATED ::= 0b1000_0000
POWER-MODE-CHARGING          ::= 0b0100_0000
POWER-MODE-BATTERY-CONNECTED ::= 0b0010_0000
POWER-MODE-BATTERY-ACTIVE    ::= 0b0000_1000

OTG-VBUS-STATUS-REGISTER ::= 4

// 6-9 are the data buffer registers.

// Read-write registers.
EXTEN-AND-DC-DC2-SWITCH-CONTROL-REGISTER ::= 0x10

POWER-OUTPUT-CONTROL-REGISTER ::= 0x12
POWER-OUTPUT-EXTEN  ::= 0b0100_0000
POWER-OUTPUT-DC-DC2 ::= 0b0001_0000
POWER-OUTPUT-LDO3   ::= 0b0000_1000
POWER-OUTPUT-LDO2   ::= 0b0000_0100
POWER-OUTPUT-DC-DC3 ::= 0b0000_0010
POWER-OUTPUT-DC-DC1 ::= 0b0000_0001

DC-DC2-VOLTAGE-SETTING-REGISTER ::= 0x23
DC-DC1-VOLTAGE-SETTING-REGISTER ::= 0x26
DC-DC3-VOLTAGE-SETTING-REGISTER ::= 0x27
DC-DC-VOLTAGE-SETTING-MASK ::= 0b0111_1111

// Note that some voltages can be encoded that are not supported.
dc-dc-millivolt-to-register mv/int -> int:
  if not 700 <= mv < 3900: throw "mV must be in range 700 - 3989"
  return (mv - 700) / 25

DC-DC2-VOLTAGE-SLOPE-PARAMETER-SETTING-REGISTER ::= 0x25

// Low 4 bits are LOD3, high 4 are LDO2.
LDO2-3-VOLTAGE-SETTING-REGISTER ::= 0x28
LDO2-VOLTAGE-MASK ::= 0xf0
LDO3-VOLTAGE-MASK ::= 0x0f

ldo3-millivolt-to-register mv/int -> int:
  if not 1800 <= mv < 3400: throw "mV must be in range 1800 - 3399"
  return (mv - 1800) / 100

ldo2-millivolt-to-register mv/int -> int:
  return (ldo3-millivolt-to-register mv) << 4

VBUS-IPSOUT-PATH-SETTING-REGISTER ::= 0x30
VBUS-IPSOUT-PATH-PIN-CONTROL  := 0b1000_0000
VBUS-IPSOUT-PATH-ALWAYS-OPEN  := 0b0000_0000
VBUS-VHOLD-PRESSURE-LIMITING  := 0b0100_0000
VBUS-VHOLD-UNLIMITED-PRESSURE := 0b0000_0000
VBUS-VHOLD-SETUP-MASK         := 0b0011_1000
VBUS-VHOLD-SETUP-4-0          := 0b0000_0000
VBUS-VHOLD-SETUP-4-1          := 0b0000_1000
VBUS-VHOLD-SETUP-4-2          := 0b0001_0000
VBUS-VHOLD-SETUP-4-3          := 0b0001_1000
VBUS-VHOLD-SETUP-4-4          := 0b0010_0000  // Default 4.4V.
VBUS-VHOLD-SETUP-4-5          := 0b0010_1000
VBUS-VHOLD-SETUP-4-6          := 0b0011_0000
VBUS-VHOLD-SETUP-4-7          := 0b0011_1000
VBUS-CURRENT-LIMIT-CONTROL-ENABLE-ON             ::= 0b0000_0010
VBUS-CURRENT-LIMIT-CONTROL-ENABLE-OFF            ::= 0b0000_0000
VBUS-CURRENT-LIMIT-CONTROL-CURRENT-SELECTION-100 ::= 0b0000_0001
VBUS-CURRENT-LIMIT-CONTROL-CURRENT-SELECTION-500 ::= 0b0000_0000

V-OFF-SHUTDOWN-VOLTAGE-SETTING-REGISTER ::= 0x31

SHUTDOWN-BATTERY-DETECTION-CHGLED-CONTROL-REGISTER ::= 0x32

CHARGE-CONTROL-REGISTER-1 ::= 0x33
CHARGE-INTERNAL-ENABLE-MASK         ::= 0b1000_0000
CHARGE-INTERNAL-ENABLE              ::= 0b1000_0000
CHARGE-INTERNAL-DISABLE             ::= 0b0000_0000
CHARGE-INTERNAL-TARGET-VOLTAGE-MASK ::= 0b0110_0000
CHARGE-INTERNAL-TARGET-VOLTAGE-4-10 ::= 0b0000_0000
CHARGE-INTERNAL-TARGET-VOLTAGE-4-15 ::= 0b0010_0000
CHARGE-INTERNAL-TARGET-VOLTAGE-4-20 ::= 0b0100_0000
CHARGE-INTERNAL-TARGET-VOLTAGE-4-36 ::= 0b0110_0000
CHARGE-INTERNAL-END-CURRENT-MASK    ::= 0b0001_0000
CHARGE-INTERNAL-END-CURRENT-10      ::= 0b0000_0000
CHARGE-INTERNAL-END-CURRENT-15      ::= 0b0001_0000
CHARGE-INTERNAL-CURRENT-MASK        ::= 0b0000_1111

charge-internal-milliamp-to-register ma/int -> int:
  if not 100 <= ma <= 1320: throw "Invalid charging mA"
  return (ma - 100) / 80  // Produces 0-15.

charge-internal-target-millivolts-to-register mv/int -> int:
  if mv == 4360: return 0b0110_0000
  else if mv == 4200: return 0b0100_0000
  else if mv == 4150: return 0b0010_0000
  else if mv == 4100: return 0b0000_0000
  else: throw "Invalid target mV"

charge-external-milliamp-to-register ma/int -> int:
  if not 300 <= ma <= 1000: throw "Invalid internal charging mA"
  return ((ma - 300) / 100) << 3  // Produces 0-7, shifted up 3 bits.

CHARGE-CONTROL-REGISTER-2 ::= 0x34

BACKUP-BATTERY-CHARGE-CONTROL-REGISTER ::= 0x35
BACKUP-BATTERY-CHARGING-ENABLED  ::= 0b1000_0000
BACKUP-BATTERY-CHARGING-DISABLED ::= 0b0000_0000
BACKUP-BATTERY-CHARGING-TARGET-VOLTAGE-MASK     ::= 0b0110_0000
BACKUP-BATTERY-CHARGING-TARGET-3-1              ::= 0b0000_0000
BACKUP-BATTERY-CHARGING-TARGET-3-0              ::= 0b0010_0000  // Or 0b0100_0000 according to data sheet.
BACKUP-BATTERY-CHARGING-TARGET-2-5              ::= 0b0110_0000
BACKUP-BATTERY-CHARGE-CONTROL-REGISTER-RESERVED ::= 0b0001_1100  // Reserved and unchangable in data sheet.
BACKUP-BATTERY-CHARGING-CURRENT-MASK            ::= 0b0000_0011
BACKUP-BATTERY-CHARGING-CURRENT-50              ::= 0b0000_0000  // µA.
BACKUP-BATTERY-CHARGING-CURRENT-100             ::= 0b0000_0001
BACKUP-BATTERY-CHARGING-CURRENT-200             ::= 0b0000_0010
BACKUP-BATTERY-CHARGING-CURRENT-400             ::= 0b0000_0011

PEK-PARAMETER-SETTING-REGISTER ::= 0x36
BOOT-TIME-MASK    ::= 0b1100_0000
BOOT-TIME-128-MS  ::= 0b0000_0000
BOOT-TIME-512-MS  ::= 0b0100_0000  // Default.
BOOT-TIME-1000-MS ::= 0b1000_0000
BOOT-TIME-2000-MS ::= 0b1100_0000
LONG-PRESS-TIME-MASK    ::= 0b0011_0000
LONG-PRESS-TIME-1000-MS ::= 0b0000_0000
LONG-PRESS-TIME-1500-MS ::= 0b0001_0000  // Default.
LONG-PRESS-TIME-2000-MS ::= 0b0010_0000
LONG-PRESS-TIME-2500-MS ::= 0b0011_0000
LONG-PRESS-FUNCTION-MASK      ::= 0b0000_1000
LONG-PRESS-AUTOMATIC-SHUTDOWN ::= 0b0000_1000
LONG-PRESS-TURN-ON            ::= 0b0000_0000  // Default.
PWROK-SIGNAL-DELAY-MASK       ::= 0b0000_0100
PWROK-SIGNAL-32               ::= 0b0000_0000  // 32ms.
PWROK-SIGNAL-64               ::= 0b0000_0100  // 64ms.  Default.
SHUTDOWN-DURATION-MASK        ::= 0b0000_0011
SHUTTOWN-DURATION-4           ::= 0b0000_0000
SHUTTOWN-DURATION-6           ::= 0b0000_0001  // 6s.  Default.
SHUTTOWN-DURATION-8           ::= 0b0000_0010
SHUTTOWN-DURATION-10          ::= 0b0000_0011

CONVERTER-OPERATING-FREQUENCY-SETTING-REGISTER ::= 0x37

BATTERY-CHARGING-LOW-TEMPERATURE-ALARM-SETTING-REGISTER ::= 0x38

BATTERY-CHARGING-HIGH-TEMPERATURE-ALARM-SETTING-REGISTER ::= 0x39

APS-LOW-POWER-LEVEL-1-SETTING-REGISTER ::= 0x3A

APS-LOW-POWER-LEVEL-2-SETTING-REGISTER ::= 0x3B

BATTERY-DISCHARGE-LOW-TEMPERATURE-ALARM-SETTING-REGISTER ::= 0x3C

BATTERY-DISCHARGE-HIGH-TEMPERATURE-ALARM-SETTING-REGISTER ::= 0x3D

DCDC-WORKING-MODE-SETTING-REGISTER ::= 0x80

ADC-ENABLE-SETTING-REGISTER-1 ::= 0x82
ADC-ENABLE-BATTERY-VOLTAGE ::= 0b1000_0000
ADC-ENABLE-BATTERY-CURRENT ::= 0b0100_0000
ADC-ENABLE-ACIN-VOLTAGE    ::= 0b0010_0000
ADC-ENABLE-ACIN-CURRENT    ::= 0b0001_0000
ADC-ENABLE-VBUS-VOLTAGE    ::= 0b0000_1000
ADC-ENABLE-VBUS-CURRENT    ::= 0b0000_0100
ADC-ENABLE-APS-VOLTAGE     ::= 0b0000_0010
ADC-ENABLE-TS-PIN          ::= 0b0000_0001

ADC-ENABLE-SETTING-REGISTER-2 ::= 0x83
ADC-ENABLE-INTERNAL-TEMPERATURE ::= 0b1000_0000
ADC-ENABLE-GPIO-0               ::= 0b0000_1000
ADC-ENABLE-GPIO-1               ::= 0b0000_0100
ADC-ENABLE-GPIO-2               ::= 0b0000_0010
ADC-ENABLE-GPIO-3               ::= 0b0000_0001

ADC-SAMPLING-RATE-SETTING-TS-PIN-CONTROL-REGISTER ::= 0x85

GPIO-3-0-INPUT-RANGE-SETTING-REGISTER ::= 0x85

TIMER-CONTROL-REGISTER ::= 0x8A

VBUS-MONITORING-SETTING-REGISTER ::= 0x8B

OVER-TEMPERATURE-SHUTDOWN-CONTROL-REGISTER ::= 0x8F

GPIO-0-CONTROL-REGISTER ::= 0x90
GPIO-1-CONTROL-REGISTER ::= 0x92
GPIO-2-CONTROL-REGISTER ::= 0x93
GPIO-CONTROL-MASK                            ::= 0b111
GPIO-CONTROL-NMOS-OPEN-DRAIN-OUTPUT          ::= 0b000
GPIO-CONTROL-UNIVERSAL-INPUT-FUNCTION        ::= 0b001
// Only for GPIO 0.
GPIO-CONTROL-LOW-NOISE-LDO                   ::= 0b010
// Only for GPIO 1 and 2.
GPIO-CONTROL-PWM-2-OUTPUT-HIGH-LEVEL-IS-VINT ::= 0b010  // Marked "do not can be less than 100k pull-down-resistor" in data sheet.
GPIO-CONTROL-KEEP                            ::= 0b011
GPIO-CONTROL-ADC-ENTER                       ::= 0b100
GPIO-CONTROL-LOW-OUTPUT                      ::= 0b101
GPIO-CONTROL-FLOATING                        ::= 0b110  // Or 0b111.

GPIO-0-LDO-MODE-OUTPUT-VOLTAGE-SETTING-REGISTER ::= 0x91
LDO-OUTPUT-VOLTAGE-MASK ::= 0xF0

ldo-output-voltage-to-register mv/int -> int:
  if not 1800 <= mv <= 3300: throw "LDO output voltage must be between 1800mV and 3300mV"
  return ((mv - 1800) / 100) << 4

GPIO-2-0-SIGNAL-STATUS-REGISTER ::= 0x94
GPIO-2-READ-INPUT    ::= 0b0100_0000
GPIO-1-READ-INPUT    ::= 0b0010_0000
GPIO-0-READ-INPUT    ::= 0b0001_0000
// 0 = low, 1 = floating.
GPIO-2-WRITE-OUTPUT  ::= 0b0000_0100
GPIO-1-WRITE-OUTPUT  ::= 0b0000_0010
GPIO-0-WRITE-OUTPUT  ::= 0b0000_0001

GPIO-4-3-FUNCTION-CONTROL-REGISTER ::= 0x95
GPIO-4-3-FEATURES-MASK      ::= 0b1000_0000
GPIO-4-3-FEATURES-ENABLE    ::= 0b1000_0000
GPIO-4-3-FEATURES-DISABLE   ::= 0b0000_0000
GPIO-4-FUNCTION-MASK        ::= 0b0000_1100
GPIO-3-FUNCTION-MASK        ::= 0b0000_0011
GPIO-3-EXTERNAL-CHARGING-CONTROL   ::= 0b00
GPIO-3-NMOS-OPEN-DRAIN-OUTPUT      ::= 0b01
GPIO-3-UNIVERSAL-INPUT-PORT        ::= 0b10
GPIO-3-ADC-INPUT                   ::= 0b11
GPIO-4-EXTERNAL-CHARGING-CONTROL ::= 0b0000
GPIO-4-NMOS-OPEN-DRAIN-OUTPUT    ::= 0b0100
GPIO-4-UNIVERSAL-INPUT-PORT      ::= 0b1000

GPIO-4-3-SIGNAL-STATUS-REGISTER ::= 0x96
GPIO-4-READ-INPUT   ::= 0b0010_0000
GPIO-3-READ-INPUT   ::= 0b0001_0000
GPIO-4-WRITE-OUTPUT ::= 0b0000_0010
GPIO-3-WRITE-OUTPUT ::= 0b0000_0001

/// Set the given bits to 1 in the register.  If the mask is given
///   then the bits in the mask are first cleared.
set-bits device register/int bits/int --mask=bits:
  reg := (device.registers.read-bytes register 1)
  reg[0] = (reg[0] & (mask ^ 0xff)) | bits
  device.registers.write-bytes register reg

/// Clear the given bits in the register. 
clear-bits device register bits:
  reg := (device.registers.read-bytes register 1)
  reg[0] &= ~bits
  device.registers.write-bytes register reg

REGISTER-TO-NAME ::= {
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
