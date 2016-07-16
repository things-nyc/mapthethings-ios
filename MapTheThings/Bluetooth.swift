//
//  Bluetooth.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/13.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import Foundation
import CoreBluetooth

/*
"Device Name" type="org.bluetooth.characteristic.gap.device_name" uuid="2A00"
 "Name": utf8s
 
 "org.bluetooth.characteristic.manufacturer_name_string" uuid="2A29" name="Manufacturer Name String"
 "Manufacturer Name": utf8s
 
 type="org.bluetooth.characteristic.firmware_revision_string" uuid="2A26" name="Firmware Revision String"
 "Firmware Revision": utf8s
 
 */

let loraService = CBUUID(string: "00001830-0000-1000-8000-00805F9B34FB")
let deviceInfoService = CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB")
let nodeServices : [CBUUID]? = [loraService, deviceInfoService]

let loraCommandCharacteristic = CBUUID(string: "00002AD0-0000-1000-8000-00805F9B34FB")
let loraWritePacketCharacteristic = CBUUID(string: "00002AD1-0000-1000-8000-00805F9B34FB")
let loraDevAddrCharacteristic = CBUUID(string: "00002AD2-0000-1000-8000-00805F9B34FB")
let loraNodeCharacteristics : [CBUUID]? = [loraCommandCharacteristic, loraWritePacketCharacteristic, loraDevAddrCharacteristic]

extension UInt16 {
    var data: NSData {
        var int = self
        return NSData(bytes: &int, length: sizeof(UInt16))
    }
}

public class BluetoothNode : NSObject, CBPeripheralDelegate {
    let peripheral : CBPeripheral
    
    public init(peripheral : CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        
        self.peripheral.delegate = self
        self.peripheral.discoverServices(nodeServices)
    }
    
    public var identifier : NSUUID {
        return self.peripheral.identifier
    }
    
    @objc public func peripheralDidUpdateName(peripheral: CBPeripheral) {
        debugPrint("peripheralDidUpdateName", peripheral.name)
    }
    @objc public func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        debugPrint("peripheral didModifyServices", peripheral.name, invalidatedServices)
    }
    @objc public func peripheralDidUpdateRSSI(peripheral: CBPeripheral, error: NSError?) {
        debugPrint("peripheralDidUpdateRSSI", peripheral.name, error)
    }
    @objc public func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        debugPrint("peripheral didReadRSSI", peripheral.name, RSSI, error)
    }
    @objc public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        debugPrint("peripheral didDiscoverServices", peripheral.name, peripheral.services, error)
        peripheral.services?.forEach({ (service) in
            if service.UUID.isEqual(loraService) {
                peripheral.discoverCharacteristics(loraNodeCharacteristics, forService: service)
            }
            else {
                peripheral.discoverCharacteristics(nil, forService: service)
            }
        })
    }
    @objc public func peripheral(peripheral: CBPeripheral, didDiscoverIncludedServicesForService service: CBService, error: NSError?) {
        debugPrint("peripheral didDiscoverIncludedServicesForService", peripheral.name, service, error)
    }
    @objc public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        debugPrint("peripheral didDiscoverCharacteristicsForService", peripheral.name, service, service.characteristics, error)
        service.characteristics!.forEach { (characteristic) in
            if characteristic.UUID.isEqual(loraWritePacketCharacteristic) {
                let data = "1234".dataUsingEncoding(NSUTF8StringEncoding)
                debugPrint("Writing to characteristic", characteristic, data)
                peripheral.writeValue(data!, forCharacteristic: characteristic, type: CBCharacteristicWriteType.WithResponse)
                //peripheral.readValueForCharacteristic(characteristic)
            }
            else if characteristic.UUID.isEqual(loraDevAddrCharacteristic) {
                let bytes : [UInt8] = [0xAA, 0xBB, 0xCC, 0xFF]
                let data = NSData(bytes: bytes, length: bytes.count)
                debugPrint("Writing to characteristic", characteristic, data)
                peripheral.writeValue(data, forCharacteristic: characteristic, type: CBCharacteristicWriteType.WithResponse)
            }
            else if characteristic.UUID.isEqual(loraCommandCharacteristic) {
                let command : UInt16 = 500
                debugPrint("Writing to characteristic", characteristic, command)
                peripheral.writeValue(command.data, forCharacteristic: characteristic, type: CBCharacteristicWriteType.WithResponse)
            }
                
            else {
                peripheral.readValueForCharacteristic(characteristic)
            }
        }
    }
    @objc public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        let value = String(data: characteristic.value!, encoding: NSUTF8StringEncoding)
        debugPrint("peripheral didUpdateValueForCharacteristic", peripheral.name, characteristic, value, error)
    }
    @objc public func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        debugPrint("peripheral didWriteValueForCharacteristic", peripheral.name, characteristic, error)
    }
    @objc public func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        debugPrint("peripheral didUpdateNotificationStateForCharacteristic", peripheral.name, characteristic, error)
    }
    @objc public func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        debugPrint("peripheral didDiscoverDescriptorsForCharacteristic", peripheral.name, characteristic, error)
    }
    @objc public func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        debugPrint("peripheral didUpdateValueForDescriptor", peripheral.name, descriptor, error)
    }
    @objc public func peripheral(peripheral: CBPeripheral, didWriteValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        debugPrint("peripheral didWriteValueForDescriptor", peripheral.name, descriptor, error)
    }
}

public class Bluetooth : NSObject, CBCentralManagerDelegate {
    let queue = dispatch_queue_create("Bluetooth", DISPATCH_QUEUE_SERIAL)
    var central : CBCentralManager? = nil
    var nodes : Dictionary<NSUUID, BluetoothNode> = Dictionary()
    var connections : Array<CBPeripheral> = Array()
    var connecting : CBPeripheral? = nil
    
    public init(savedIdentifiers: [NSUUID]) {
        super.init()
        
        self.central = CBCentralManager.init(delegate: self, queue: self.queue)
        
        let knownPeripherals =
            self.central!.retrievePeripheralsWithIdentifiers(savedIdentifiers)
        if !knownPeripherals.isEmpty {
            knownPeripherals.forEach({ (p) in
                self.central!.connectPeripheral(p, options: nil)
            })
        }
        else {
            self.central!.scanForPeripheralsWithServices(nodeServices, options: nil)
        }
    }
    
    var nodeIdentifiers : [NSUUID] {
        return Array(nodes.keys)
    }
    @objc public func centralManagerDidUpdateState(central: CBCentralManager) {
        debugPrint("centralManagerDidUpdateState", central.state)
    }
    @objc public func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        debugPrint("centralManager willRestoreState")
    }
    private func attemptConnection() {
        if (self.connections.count>0) {
            let peripheral = self.connections.removeAtIndex(0)
            self.connecting = peripheral
            self.central!.connectPeripheral(peripheral, options: nil)
        }
    }
    @objc public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        debugPrint("centralManager didDiscoverPeripheral", peripheral.name, advertisementData, RSSI)
        self.connections.append(peripheral)
        if (self.connecting==nil) {
            attemptConnection()
        }
//        [
//        CBConnectPeripheralOptionNotifyOnConnectionKey: YES,
//        CBConnectPeripheralOptionNotifyOnDisconnectionKey: YES,
//        CBConnectPeripheralOptionNotifyOnNotificationKey: YES
//        ]
    }

    @objc public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        debugPrint("centralManager didConnectPeripheral", peripheral.name)
        
        let node = BluetoothNode(peripheral: peripheral)
        self.nodes[node.identifier] = node
        self.connecting = nil
    }
    
    @objc public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        debugPrint("centralManager didFailToConnectPeripheral", peripheral.name, error)
        attemptConnection()
    }
    
    @objc public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        debugPrint("centralManager didDisconnectPeripheral", peripheral.name, error)
        attemptConnection()
    }
}