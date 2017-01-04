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
 
 TODO: Add TXresult characteristic to loraService
 */

let loraService = CBUUID(string: "00001830-0000-1000-8000-00805F9B34FB")
let deviceInfoService = CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB")
let batteryService = CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB")
let logService = CBUUID(string: "00001831-0000-1000-8000-00805F9B34FB")
let nodeServices : [CBUUID]? = [loraService, deviceInfoService, batteryService, logService]

let batteryLevelCharacteristic =    CBUUID(string: "00002A19-0000-1000-8000-00805F9B34FB")
let logStringCharacteristic =       CBUUID(string: "00002AD6-0000-1000-8000-00805F9B34FB")
let transmitResultCharacteristic =  CBUUID(string: "00002AD7-0000-1000-8000-00805F9B34FB")

let loraCommandCharacteristic =     CBUUID(string: "00002AD0-0000-1000-8000-00805F9B34FB")
let loraWritePacketCharacteristic = CBUUID(string: "00002AD1-0000-1000-8000-00805F9B34FB")
let loraDevAddrCharacteristic =     CBUUID(string: "00002AD2-0000-1000-8000-00805F9B34FB")
let loraNwkSKeyCharacteristic =     CBUUID(string: "00002AD3-0000-1000-8000-00805F9B34FB")
let loraAppSKeyCharacteristic =     CBUUID(string: "00002AD4-0000-1000-8000-00805F9B34FB")
let loraSpreadingFactorCharacteristic =
                                    CBUUID(string: "00002AD5-0000-1000-8000-00805F9B34FB")

let loraNodeCharacteristics : [CBUUID]? = [
    loraCommandCharacteristic,
    loraWritePacketCharacteristic,
    loraDevAddrCharacteristic,
    loraNwkSKeyCharacteristic,
    loraAppSKeyCharacteristic,
    loraSpreadingFactorCharacteristic,
]

extension UInt16 {
    var data: NSData {
        var int = self
        return NSData(bytes: &int, length: sizeof(UInt16))
    }
}

extension UInt8 {
    var data: NSData {
        var int = self
        return NSData(bytes: &int, length: sizeof(UInt8))
    }
}

extension CBCharacteristic {
    var nsUUID : NSUUID {
        var s = self.UUID.UUIDString
        if s.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)==4 {
            s = "0000\(s)-0000-1000-8000-00805F9B34FB"
        }
        return NSUUID(UUIDString: s)!
    }
}

func readInteger<T : IntegerType>(data : NSData, start : Int) -> T {
    var d : T = 0
    data.getBytes(&d, range: NSRange(location: start, length: sizeof(T)))
    return d
}

func setAppStateDeviceAttribute(id: NSUUID, name: String?, characteristic: CBCharacteristic, value: NSData, error: NSError?) {
    let s = String(data: value, encoding: NSUTF8StringEncoding)
    debugPrint("peripheral didUpdateValueForCharacteristic", name, characteristic, s, error)
    updateAppState { (old) -> AppState in
        if var dev = old.bluetooth[id] {
            switch characteristic.UUID {
            case loraDevAddrCharacteristic:
                dev.devAddr = value
            case loraNwkSKeyCharacteristic:
                dev.nwkSKey = value
            case loraAppSKeyCharacteristic:
                dev.appSKey = value
            case batteryLevelCharacteristic:
                dev.battery = readInteger(value, start: 0)
            case logStringCharacteristic:
                let msg = String(data: value, encoding: NSUTF8StringEncoding)!
                dev.log.append(msg)
            case loraSpreadingFactorCharacteristic:
                let sf:UInt8 = readInteger(value, start: 0)
                dev.spreadingFactor = sf
            default:
                return old // No changes
            }
            var state = old
            state.bluetooth[id] = dev
            return state
        }
        else {
            debugPrint("Should find \(id) in device list")
            return old
        }
    }
}

public protocol LoraNode {
    var  identifier : NSUUID { get }
    func sendPacket(data : NSData) -> Bool
    func setSpreadingFactor(sf: UInt8) -> Bool
}

func observeSpreadingFactor(device: LoraNode) {
    appStateObservable.observeNext {update in
        let oldDev = update.old.bluetooth[device.identifier]
        if let dev = update.new.bluetooth[device.identifier],
            let sf = dev.spreadingFactor
            where oldDev==nil || oldDev!.spreadingFactor==nil || sf != oldDev!.spreadingFactor! {
            device.setSpreadingFactor(sf)
        }
    }
}

public class FakeBluetoothNode : NSObject, LoraNode {
    let uuid: NSUUID
    
    override public init() {
        self.uuid = NSUUID()
        super.init()
        observeSpreadingFactor(self)
    }
    
    public var identifier : NSUUID {
        return self.uuid
    }

    public func setSpreadingFactor(sf: UInt8) -> Bool {
        debugPrint("Set spreading factor: \(sf)")
        return true
    }
    
    public func sendPacket(data : NSData) -> Bool {
        debugPrint("Sending fake packet: \(data)")
        return true
    }
}

public class BluetoothNode : NSObject, LoraNode, CBPeripheralDelegate {
    let peripheral : CBPeripheral
    var characteristics : Dictionary<String, CBCharacteristic> = Dictionary()
    
    public init(peripheral : CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        
        self.peripheral.delegate = self
        self.peripheral.discoverServices(nodeServices)
        
        observeSpreadingFactor(self)
    }
    
    public var identifier : NSUUID {
        return self.peripheral.identifier
    }
    
    public func sendPacket(data : NSData) -> Bool {
        if let characteristic = self.characteristics[loraWritePacketCharacteristic.UUIDString] {
            debugPrint("Sending packet", data)
            peripheral.writeValue(data, forCharacteristic: characteristic, type: CBCharacteristicWriteType.WithResponse)
            return true
        }
        else {
            debugPrint("Unable to send packet - Write Packet characteristic unavailable.")
            return false
        }
    }
    
    public func setSpreadingFactor(sf : UInt8) -> Bool {
        if let characteristic = self.characteristics[loraSpreadingFactorCharacteristic.UUIDString] {
            debugPrint("Setting SF", sf)
            peripheral.writeValue(sf.data, forCharacteristic: characteristic, type: CBCharacteristicWriteType.WithResponse)
            return true
        }
        else {
            debugPrint("Unable to set SF - Spreading Factor characteristic unavailable.")
            return false
        }
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
            else if service.UUID.isEqual(loraService) {
                peripheral.discoverCharacteristics([logStringCharacteristic], forService: service)
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
            debugPrint("Set characteristic: ", characteristic.nsUUID.UUIDString)
            self.characteristics[characteristic.nsUUID.UUIDString] = characteristic
            if characteristic.UUID.isEqual(loraDevAddrCharacteristic) ||
                characteristic.UUID.isEqual(loraNwkSKeyCharacteristic) ||
                characteristic.UUID.isEqual(loraAppSKeyCharacteristic) ||
                characteristic.UUID.isEqual(loraSpreadingFactorCharacteristic)
            {
                peripheral.readValueForCharacteristic(characteristic)
            }
            else if characteristic.UUID.isEqual(batteryLevelCharacteristic) ||
                characteristic.UUID.isEqual(logStringCharacteristic) {
                debugPrint("Subscribing to characteristic", characteristic)
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
            }
//            else if characteristic.UUID.isEqual(loraCommandCharacteristic) {
//                let command : UInt16 = 500
//                debugPrint("Writing to characteristic", characteristic, command)
//                peripheral.writeValue(command.data, forCharacteristic: characteristic, type: CBCharacteristicWriteType.WithResponse)
//            }
                
            else {
                peripheral.readValueForCharacteristic(characteristic)
            }
        }
    }
    @objc public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if let value = characteristic.value {
            setAppStateDeviceAttribute(peripheral.identifier, name: peripheral.name, characteristic: characteristic, value: value, error: error)
        }
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
    var nodes : Dictionary<NSUUID, LoraNode> = Dictionary()
    var connections : Array<CBPeripheral> = Array()
    var connecting : CBPeripheral? = nil
    
    public init(savedIdentifiers: [NSUUID]) {
        super.init()
        
        self.central = CBCentralManager.init(delegate: self, queue: self.queue,
                                            options: [CBCentralManagerOptionRestoreIdentifierKey: "MapTheThingsManager"])
        
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (Int64)(5 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), {
                let knownPeripherals =
                    self.central!.retrievePeripheralsWithIdentifiers(savedIdentifiers)
                if !knownPeripherals.isEmpty {
                    knownPeripherals.forEach({ (p) in
                        self.central!.connectPeripheral(p, options: nil)
                    })
                }
                else {
                    self.rescan()
                }
            })
    }
    
    public func addFakeNode() -> FakeBluetoothNode {
        let fake = FakeBluetoothNode()
        connectNode(fake)
        return fake
    }
    
    public func rescan() {
        self.central!.scanForPeripheralsWithServices(nodeServices, options: nil)
    }
    
    var nodeIdentifiers : [NSUUID] {
        return Array(nodes.keys)
    }
    public func node(id: NSUUID) -> LoraNode? {
        return nodes[id]
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
        
        connectNode(node)
    }
    
    public func connectNode(node: LoraNode) {
        self.nodes[node.identifier] = node
        self.connecting = nil

        updateAppState { (old) -> AppState in
            var state = old
            var dev = Device(uuid: node.identifier)
            if let known = state.bluetooth[node.identifier] {
                dev = known
                assert(dev.identifier.isEqual(node.identifier), "Device id should be same as peripheral id")
            }
            dev.connected = true // Indicate that the peripheral is connected
            state.bluetooth[node.identifier] = dev
            return state
        }
    }
    
    @objc public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        debugPrint("centralManager didFailToConnectPeripheral", peripheral.name, error)
        attemptConnection()
    }
    
    @objc public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        // Ensure that when bluetooth device is disconnected, the device.connected = false
        debugPrint("centralManager didDisconnectPeripheral", peripheral.name, error)
        attemptConnection()
        updateAppState { (old) -> AppState in
            if var dev = old.bluetooth[peripheral.identifier] {
                assert(dev.identifier.isEqual(peripheral.identifier), "Device id should be same as peripheral id")
                dev.connected = false // Indicate that the peripheral is disconnected
                var state = old
                state.bluetooth[peripheral.identifier] = dev
                return state
            }
            else {
                return old
            }
        }
    }
}
