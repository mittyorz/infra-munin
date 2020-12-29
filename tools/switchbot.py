#!/usr/bin/env python3
# -*- python -*-

from bluepy import btle
import struct
import sys
import os

if len(sys.argv) < 2:
    sys.exit(f'usage: {sys.argv[0]} MAC_address_of_SwtichBot [dir/path/to/save/result]')

# MAC address for SwitchbotScanDelegate should be lower case
mac = sys.argv[1].lower()
dir = os.getcwd()
if len(sys.argv) >= 3:
    dir = sys.argv[2]
    if not os.path.isdir(dir):
        sys.exit(f'{sys.argv[0]}: {dir} is not directory')

class SwitchbotScanDelegate(btle.DefaultDelegate):
    def __init__(self, macaddr):
        btle.DefaultDelegate.__init__(self)
        self.sensorValue = None
        self.macaddr = macaddr

    def handleDiscovery(self, dev, isNewDev, isNewData):
        if dev.addr == self.macaddr:
            for (adtype, desc, value) in dev.getScanData():  
                if desc == '16b Service Data':
                    self._decodeSensorData(value)

    def _decodeSensorData(self, valueStr):
        valueBinary = bytes.fromhex(valueStr[4:])
        batt = valueBinary[2] & 0b01111111
        isTemperatureAboveFreezing = valueBinary[4] & 0b10000000
        temp = ( valueBinary[3] & 0b00001111 ) / 10 + ( valueBinary[4] & 0b01111111 )
        if not isTemperatureAboveFreezing:
            temp = -temp
        humid = valueBinary[5] & 0b01111111
        self.sensorValue = {
            'Temperature': temp,
            'Humidity': humid,
            'BatteryVoltage': batt
        }

scanner = btle.Scanner().withDelegate(SwitchbotScanDelegate(mac))
scanner.scan(5.0)

if scanner.delegate.sensorValue is None:
    sys.exit(f'{sys.argv[0]}: {mac} was not discovered')

# remove ':' from MAC address
filename = mac.replace(':', '')
with open(f'{dir}/{filename}', 'w') as f:
    for k, v in scanner.delegate.sensorValue.items():
        print(k, v, sep=' ', file=f)
