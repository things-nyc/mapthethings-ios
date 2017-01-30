//
//  Bluetooth.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/13.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import Foundation
import CoreBluetooth
import ReactiveSwift

/*
 Every bluetooth peripheral has a UUID.
 
 The Bluetooth singleton object maintains a dictionary of nodes indexed by UUID. The values
 are instances of LoraNode, which (currently) may be either a BluetoothNode or a FakeBluetoothNode.
 
 When Bluetooth starts, it uses either a list of known peripherals or starts a scan of peripherals.
 
 When a peripheral is discovered, it gets added to the Bluetooth.nodes dictionary and a Device object
 representing its state is added to AppState.bluetooth dictionary (also indexed by same UUID).
 
 At this point, we have not established a bluetooth connection to any device.
 
 When AppState.connectToDevice is assigned a NSUUID, an observer on Bluetooth object initiates
 a connect operation on the peripheral identified by state.activeDeviceID.
 */

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
let batteryService = CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB")
let logService = CBUUID(string: "00001831-0000-1000-8000-00805F9B34FB")
let nodeServices : [CBUUID]? = [loraService, deviceInfoService, batteryService, logService]

let batteryLevelCharacteristic =    CBUUID(string: "00002A19-0000-1000-8000-00805F9B34FB")
let logStringCharacteristic =       CBUUID(string: "00002AD6-0000-1000-8000-00805F9B34FB")

let loraCommandCharacteristic =     CBUUID(string: "00002AD0-0000-1000-8000-00805F9B34FB")
let loraWritePacketCharacteristic = CBUUID(string: "00002AD1-0000-1000-8000-00805F9B34FB")
let loraWritePacketWithAckCharacteristic =
                                    CBUUID(string: "00002ADB-0000-1000-8000-00805F9B34FB")
let loraDevAddrCharacteristic =     CBUUID(string: "00002AD2-0000-1000-8000-00805F9B34FB")
let loraNwkSKeyCharacteristic =     CBUUID(string: "00002AD3-0000-1000-8000-00805F9B34FB")
let loraAppSKeyCharacteristic =     CBUUID(string: "00002AD4-0000-1000-8000-00805F9B34FB")

let loraAppKeyCharacteristic =      CBUUID(string: "00002AD7-0000-1000-8000-00805F9B34FB")
let loraAppEUICharacteristic =      CBUUID(string: "00002AD8-0000-1000-8000-00805F9B34FB")
let loraDevEUICharacteristic =      CBUUID(string: "00002AD9-0000-1000-8000-00805F9B34FB")

let loraSpreadingFactorCharacteristic =
                                    CBUUID(string: "00002AD5-0000-1000-8000-00805F9B34FB")
let transmitResultCharacteristic =  CBUUID(string: "00002ADA-0000-1000-8000-00805F9B34FB")

let loraNodeCharacteristics : [CBUUID]? = [
    loraCommandCharacteristic,
    loraWritePacketCharacteristic,
    loraWritePacketWithAckCharacteristic,
    loraDevAddrCharacteristic,
    loraNwkSKeyCharacteristic,
    loraAppSKeyCharacteristic,
    loraSpreadingFactorCharacteristic,
    transmitResultCharacteristic,
    loraAppKeyCharacteristic,
    loraAppEUICharacteristic,
    loraDevEUICharacteristic,
]

extension UInt16 {
    var data: Data {
        var int: UInt16 = self
        let buffer = UnsafeBufferPointer(start: &int, count: 1)
        return Data(buffer: buffer)
    }
}

extension UInt8 {
    var data: Data {
        var int: UInt8 = self
        let buffer = UnsafeBufferPointer(start: &int, count: 1)
        return Data(buffer: buffer)
    }
}

extension CBCharacteristic {
    var nsUUID : UUID {
        var s = self.uuid.uuidString
        if s.lengthOfBytes(using: String.Encoding.utf8)==4 {
            s = "0000\(s)-0000-1000-8000-00805F9B34FB"
        }
        return UUID(uuidString: s)!
    }
}

func readInteger<T : Integer>(_ data : Data, start : Int) -> T {
    var d : T = 0
    (data as NSData).getBytes(&d, range: NSRange(location: start, length: MemoryLayout<T>.size))
    return d
}

func storeLoraSeq(_ old_state: AppState, device: UUID, ble_seq: UInt8, lora_seq: UInt32) -> AppState {
    debugPrint("storeLoraSeq \(lora_seq) for ble: \(ble_seq)")
    var state = old_state
    // Find transmission with this device+ble_seq
    for (index, tx) in state.map.transmissions.enumerated() {
        if let tx_ble_seq = tx.ble_seq,
            let tx_dev = tx.device, (ble_seq==tx_ble_seq && device==tx_dev as UUID && tx.lora_seq==nil) {
            // There could be the same device+ble with lora_seq already set
            // - because BLE seq numbers repeat - hence lora_seq nil check.
            // TODO: Not good enough - could have failed to receive lora seq.
            // We should assume most recent is the one we just got.
            state.map.transmissions[index].lora_seq = lora_seq
            if let objID = state.map.transmissions[index].objectID {
                state.syncState.recordLoraToObject.append((objID, lora_seq))
            }
            else {
                debugPrint("No object ID to record lora seq no")
            }
        }
    }
    return state
}

func setAppStateDeviceAttribute(_ id: UUID, name: String?, characteristic: CBCharacteristic, value: Data, error: NSError?) {
    let s = String(data: value, encoding: String.Encoding.utf8)
    debugPrint("peripheral didUpdateValueForCharacteristic", name ?? "-", characteristic, s?.description ?? "-", error?.description ?? "-")
    updateAppState { (old) -> AppState in
        if var dev = old.bluetooth[id] {
            var state = old
            switch characteristic.uuid {
            case loraDevAddrCharacteristic:
                dev.devAddr = value
            case loraNwkSKeyCharacteristic:
                dev.nwkSKey = value
            case loraAppSKeyCharacteristic:
                dev.appSKey = value
            case loraAppKeyCharacteristic:
                dev.appKey = value
            case loraAppEUICharacteristic:
                dev.appEUI = value
            case loraDevEUICharacteristic:
                dev.devEUI = value
            case transmitResultCharacteristic:
                //                      format         ble_seq          error           lora_seq
                assert(value.count==(MemoryLayout<UInt8>.size+MemoryLayout<UInt8>.size+MemoryLayout<UInt16>.size+MemoryLayout<UInt32>.size))
                debugPrint("TX result: \(value)")
                let result_format:UInt8 = readInteger(value, start: 0)
                if result_format==1 {
                    let ble_seq:UInt8 = readInteger(value, start: MemoryLayout<UInt8>.size)
                    let error:UInt16 = readInteger(value, start: 2*MemoryLayout<UInt8>.size)
                    let lora_seq:UInt32 = readInteger(value, start: 2*MemoryLayout<UInt8>.size+MemoryLayout<UInt16>.size)
                    if error==0 {
                        state = storeLoraSeq(state, device: id, ble_seq: ble_seq, lora_seq: lora_seq)
                    }
                    else {
                        debugPrint("Received tx error result: \(error)")
                    }
                }
                else {
                    debugPrint("Received unknown result format: \(result_format)")
                }
            case batteryLevelCharacteristic:
                dev.battery = readInteger(value, start: 0)
            case logStringCharacteristic:
                let msg = String(data: value, encoding: String.Encoding.utf8)!
                dev.log.append(msg)
            case loraSpreadingFactorCharacteristic:
                let sf:UInt8 = readInteger(value, start: 0)
                dev.spreadingFactor = sf
            default:
                return old // No changes
            }
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
    var  identifier : UUID { get }
    func requestConnection(_ central: CBCentralManager)
    func onConnect()
    func requestDisconnect(_ central: CBCentralManager)
    func onDisconnect()
    func sendPacket(_ data : Data) -> Bool
    func sendPacketWithAck(_ data : Data) -> UInt8? // ble sequence number, or null on failure or unavailable
    func setSpreadingFactor(_ sf: UInt8) -> Bool
    func assignOTAA(_ appKey: Data, appEUI: Data, devEUI: Data)
}

func markConnectStatus(_ id: UUID, connected: Bool) {
    updateAppState { (old) -> AppState in
//        assert(dev.identifier.isEqual(peripheral.identifier), "Device id should be same as peripheral id")
        var state = old
        state.bluetooth[id]?.connected = connected
        return state
    }
}

func observeSpreadingFactor(_ device: LoraNode) -> Disposable? {
    return appStateObservable.observeValues { update in
        let oldDev = update.old.bluetooth[device.identifier]
        if let dev = update.new.bluetooth[device.identifier],
            let sf = dev.spreadingFactor,
            oldDev==nil || oldDev!.spreadingFactor==nil || sf != oldDev!.spreadingFactor! {
            _ = device.setSpreadingFactor(sf)
        }
    }
}

open class FakeBluetoothNode : NSObject, LoraNode {
    let uuid: UUID
    var lora_seq: UInt32 = 100;
    var ble_seq: UInt8 = 1 // Rolling sequence number that lets us link ack messages to sends
    var sfDisposer: Disposable?
    
    override public init() {
        self.uuid = UUID()
        super.init()
        self.sfDisposer = observeSpreadingFactor(self)
    }
    
    open var identifier : UUID {
        return self.uuid
    }

    open func requestConnection(_ central: CBCentralManager) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).asyncAfter(deadline: DispatchTime.now() + Double(Int64(2 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {
            self.onConnect()
        });
    }
    
    open func onConnect() {
        markConnectStatus(self.identifier, connected: true)
    }

    open func requestDisconnect(_ central: CBCentralManager) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).asyncAfter(deadline: DispatchTime.now() + Double(Int64(2 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {
            self.onDisconnect()
        });
    }
    
    open func onDisconnect() {
        markConnectStatus(self.identifier, connected: false)
    }
    
    open func setSpreadingFactor(_ sf: UInt8) -> Bool {
        debugPrint("Set spreading factor: \(sf)")
        return true
    }
    
    open func assignOTAA(_ appKey: Data, appEUI: Data, devEUI: Data) {
        debugPrint("Assigning OTAA")
    }

    open func sendPacket(_ data : Data) -> Bool {
        debugPrint("Sending fake packet: \(data)")
        return true
    }
    open func sendPacketWithAck(_ data: Data) -> UInt8? {
        let ble_seq = self.ble_seq
        self.ble_seq += 1
        
        let lora_seq = self.lora_seq
        self.lora_seq += 1
        
        var tracked = NSData(data: ble_seq.data) as Data
        tracked.append(data)

        _ = sendPacket(tracked)
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).asyncAfter(deadline: DispatchTime.now() + Double(Int64(10 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {
                        debugPrint("Writing response sequence no \(self.ble_seq)")
                        updateAppState { (old) -> AppState in
                            return storeLoraSeq(old, device: self.uuid, ble_seq: ble_seq, lora_seq: lora_seq)
                        }
        });
        return ble_seq
    }
}

open class BluetoothNode : NSObject, LoraNode, CBPeripheralDelegate {
    let peripheral : CBPeripheral
    var characteristics : [String: CBCharacteristic] = [:]
    var ble_seq: UInt8 = 1
    var sfDisposer: Disposable?
    
    public init(peripheral : CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        
        self.peripheral.delegate = self
        self.sfDisposer = observeSpreadingFactor(self)
    }
    
    open var identifier : UUID {
        return self.peripheral.identifier
    }
    
    open func requestConnection(_ central: CBCentralManager) {
        central.connect(self.peripheral, options: nil)
    }

    open func onConnect() {
        self.peripheral.discoverServices(nodeServices)
        markConnectStatus(self.identifier, connected: true)
    }

    open func requestDisconnect(_ central: CBCentralManager) {
        central.cancelPeripheralConnection(self.peripheral)
    }
    
    open func onDisconnect() {
        self.characteristics = [:]
        self.ble_seq = 1
        markConnectStatus(self.identifier, connected: false)
    }
    
    open func sendPacket(_ data : Data) -> Bool {
        if let characteristic = self.characteristics[loraWritePacketCharacteristic.uuidString] {
            debugPrint("Sending packet", data)
            peripheral.writeValue(data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
            return true
        }
        else {
            debugPrint("Unable to send packet - Write Packet characteristic unavailable.")
            return false
        }
    }
    open func sendPacketWithAck(_ data: Data) -> UInt8? {
        if let characteristic = self.characteristics[loraWritePacketWithAckCharacteristic.uuidString] {
            debugPrint("Sending packet with ack", data)
            let ble_seq = self.ble_seq
            self.ble_seq += 1
            
            // Prepend ble_seq to actual data. ble_seq will be included in tx result report.
            var tracked = NSData(data: ble_seq.data) as Data
            tracked.append(data)
            
            peripheral.writeValue(tracked, for: characteristic,
                                  type: CBCharacteristicWriteType.withResponse)
            return ble_seq
        }
        else {
            debugPrint("Write Packet with ack characteristic unavailable.")
            return nil
        }
    }
   
    open func assignOTAA(_ appKey: Data, appEUI: Data, devEUI: Data) {
        if let charAppKey = self.characteristics[loraAppKeyCharacteristic.uuidString],
            let charAppEUI = self.characteristics[loraAppEUICharacteristic.uuidString],
            let charDevEUI = self.characteristics[loraDevEUICharacteristic.uuidString] {
            peripheral.writeValue(appKey, for: charAppKey, type: CBCharacteristicWriteType.withResponse)
            peripheral.writeValue(appEUI, for: charAppEUI, type: CBCharacteristicWriteType.withResponse)
            peripheral.writeValue(devEUI, for: charDevEUI, type: CBCharacteristicWriteType.withResponse)
        }
    }

    open func setSpreadingFactor(_ sf : UInt8) -> Bool {
        if let characteristic = self.characteristics[loraSpreadingFactorCharacteristic.uuidString] {
            debugPrint("Setting SF", sf)
            peripheral.writeValue(sf.data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
            return true
        }
        else {
            debugPrint("Unable to set SF - Spreading Factor characteristic unavailable.")
            return false
        }
    }
    
    @objc open func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        debugPrint("peripheralDidUpdateName", peripheral.name ?? "-")
    }
    @objc open func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        debugPrint("peripheral didModifyServices", peripheral.name ?? "-", invalidatedServices)
    }
    @objc open func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
        debugPrint("peripheralDidUpdateRSSI", peripheral.name ?? "-", error ?? "-")
    }
    @objc open func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        debugPrint("peripheral didReadRSSI", peripheral.name ?? "-", RSSI, error ?? "-")
    }
    @objc open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        debugPrint("peripheral didDiscoverServices", peripheral.name ?? "-", peripheral.services ?? "-", error ?? "-")
        peripheral.services?.forEach({ (service) in
            switch service.uuid {
            case loraService:
                peripheral.discoverCharacteristics(loraNodeCharacteristics, for: service)
            case logService:
                peripheral.discoverCharacteristics([logStringCharacteristic], for: service)
            default:
                peripheral.discoverCharacteristics(nil, for: service)
            }
        })
    }
    @objc open func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        debugPrint("peripheral didDiscoverIncludedServicesForService", peripheral.name ?? "-", service, error ?? "-")
    }
    @objc open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        debugPrint("peripheral didDiscoverCharacteristicsForService", peripheral.name ?? "-", service, service.characteristics ?? "-", error ?? "-")
        service.characteristics!.forEach { (characteristic) in
            debugPrint("Set characteristic: ", characteristic.nsUUID.uuidString)
            self.characteristics[characteristic.nsUUID.uuidString] = characteristic
            switch characteristic.uuid {
            case loraDevAddrCharacteristic,
                loraAppSKeyCharacteristic,
                loraNwkSKeyCharacteristic,
                loraAppKeyCharacteristic,
                loraAppEUICharacteristic,
                loraDevEUICharacteristic,
                loraSpreadingFactorCharacteristic:
                peripheral.readValue(for: characteristic)
            case batteryLevelCharacteristic,
                transmitResultCharacteristic,
                logStringCharacteristic:
                debugPrint("Subscribing to characteristic", characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
//          case loraCommandCharacteristic:
//                let command : UInt16 = 500
//                debugPrint("Writing to characteristic", characteristic, command)
//                peripheral.writeValue(command.data, forCharacteristic: characteristic,
//                  type:CBCharacteristicWriteType.WithResponse)
            default:
                peripheral.readValue(for: characteristic)
            }
        }
    }
    @objc open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value {
            setAppStateDeviceAttribute(peripheral.identifier, name: peripheral.name, characteristic: characteristic, value: value, error: error as NSError?)
        }
    }
    @objc open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        debugPrint("peripheral didWriteValueForCharacteristic", peripheral.name ?? "-", characteristic, error ?? "-")
    }
    @objc open func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        debugPrint("peripheral didUpdateNotificationStateForCharacteristic", peripheral.name ?? "-", characteristic, error ?? "-")
    }
    @objc open func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        debugPrint("peripheral didDiscoverDescriptorsForCharacteristic", peripheral.name ?? "-", characteristic, error ?? "-")
    }
    @objc open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        debugPrint("peripheral didUpdateValueForDescriptor", peripheral.name ?? "-", descriptor, error ?? "-")
    }
    @objc open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        debugPrint("peripheral didWriteValueForDescriptor", peripheral.name ?? "-", descriptor, error ?? "-")
    }
}

open class Bluetooth : NSObject, CBCentralManagerDelegate {
    let queue = DispatchQueue(label: "Bluetooth", attributes: [])
    var central : CBCentralManager!
    var nodes : [UUID: LoraNode] = [:]
    var disposeObserver: Disposable?
    
    public init(savedIdentifiers: [UUID]) {
        super.init()
        self.central = CBCentralManager.init(delegate: self, queue: self.queue,
                                             options: [CBCentralManagerOptionRestoreIdentifierKey: "MapTheThingsManager"])
        
        DispatchQueue.main.asyncAfter(
            deadline: DispatchTime.now() + Double((Int64)(5 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {
                let knownPeripherals =
                    self.central.retrievePeripherals(withIdentifiers: savedIdentifiers)
                if !knownPeripherals.isEmpty {
                    knownPeripherals.forEach({ (p) in
//                        self.central!.connectPeripheral(p, options: nil)
                        self.centralManager(self.central, didDiscover: p, advertisementData: [:], rssi: 0)
                    })
                }
                else {
                    self.rescan()
                }
            })
        self.disposeObserver = appStateObservable.observeValues({ update in
            if let activeID = update.new.viewDetailDeviceID,
                let node = self.nodes[activeID] {

                if stateValChanged(update, access: {$0.connectToDevice}) {
                    node.requestConnection(self.central)
                }

                if stateValChanged(update, access: {$0.disconnectDevice}) {
                    node.requestDisconnect(self.central)
                }
            }
            
            if stateValChanged(update, access: {$0.assignProvisioning}) {
                if let (_, deviceID) = update.new.assignProvisioning,
                    let node = self.nodes[deviceID],
                    let device = update.new.bluetooth[deviceID],
                    let appKey = device.appKey,
                    let appEUI = device.appEUI,
                    let devEUI = device.devEUI {
                    node.assignOTAA(appKey, appEUI: appEUI, devEUI: devEUI)
                }
            }
        })
    }
    
    open func addFakeNode() -> Void {
        let fake = FakeBluetoothNode()
        discoveredNode(fake, name: fake.identifier.uuidString)
    }
    
    open func rescan() {
        self.central.scanForPeripherals(withServices: nodeServices, options: nil)
    }
    
    var nodeIdentifiers : [UUID] {
        return Array(nodes.keys)
    }
    open func node(_ id: UUID) -> LoraNode? {
        return nodes[id]
    }
    @objc open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        debugPrint("centralManagerDidUpdateState", central.state)
    }
    @objc open func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        debugPrint("centralManager willRestoreState")
    }
    @objc open func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        debugPrint("centralManager didDiscoverPeripheral", peripheral.name ?? "-", advertisementData, RSSI)
        if nodes[peripheral.identifier]==nil {
            let node = BluetoothNode(peripheral: peripheral)
            discoveredNode(node, name: peripheral.name)
        }
        else {
            debugPrint("Repeated call to didDiscoverPeripheral ignored.")
        }
    }

    @objc open func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debugPrint("centralManager didConnectPeripheral", peripheral.name ?? "-")
        
        if let node = nodes[peripheral.identifier] {
            node.onConnect()
        }
    }
    
    open func discoveredNode(_ node: LoraNode, name: String?) {
        self.nodes[node.identifier] = node

        updateAppState { (old) -> AppState in
            var state = old
            let devName = name==nil ? "<UnknownDevice>" : name!
            var dev = Device(uuid: node.identifier, name: devName)
            if let known = state.bluetooth[node.identifier] {
                dev = known
                assert(dev.identifier == node.identifier, "Device id should be same as peripheral id")
            }
            dev.connected = false // Just discovered, not yet connected
            state.bluetooth[node.identifier] = dev
            return state
        }
    }
    
    @objc open func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        debugPrint("centralManager didFailToConnectPeripheral", peripheral.name ?? "-", error ?? "-")
    }
    
    @objc open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Ensure that when bluetooth device is disconnected, the device.connected = false
        debugPrint("centralManager didDisconnectPeripheral", peripheral.name ?? "-", error ?? "-")
        if let node = self.nodes[peripheral.identifier] {
            node.onDisconnect()
        }
    }
}
