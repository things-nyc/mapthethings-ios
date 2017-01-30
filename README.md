[![Build Status](https://travis-ci.org/things-nyc/mapthethings-ios.svg?branch=master)](https://travis-ci.org/things-nyc/mapthethings-ios)
# MapTheThings-iOS

The iOS app portion of [MapTheThings](http://map.thethings.nyc), the
global coverage map for The Things Network (TTN).

## Using the App
- Map view - Shows local map with latest sample data
  - Lighter green: You asked the node to send a packet.
  - Darker green: Node confirmed the app packet was sent successfully. (Whether it reached a gateway, only the server knows.)
  - Yellow: You sent a packet. (And you’re using an older version node that doesn’t ack packets, so we don’t know whether the node thinks it worked or not.)
  - Red: Packet was not sent - got an error from LoRa radio module.
  - Blue: Server reports successful transmissions received.
  - Gray: Server reports attempted transmissions here, but none received from TTN.
- Devices view
  - List shows all Bluetooth devices discovered nearby. A green dot appears next to each currently connected device.
  - Choose a device to see the device details
  - Touch the Connect button to connect to the node
  - Touch the Get OTAA button to load provisioning keys.
  - Packets will be generated and sent automatically as new GPS locations arrive.
  - Touch Resend to resend the last packet.
  - Touch Send Test to send a packet for lat/lon 10.0/10.0
  - View debug messages in the text field at the bottom of the screen.
- Messages view
  - Enter a phone number
  - Enter a message
  - Hit the Send button. Message will be transmitted via a connected node.

## Developer Notes
- We use [Cocoapods](https://cocoapods.org/). You'll need to install it and run ```pod install``` to bring in all the dependencies.
- We are now using the latest version of Swift.
- Fake a Device - Set FakeDevice=1 in ```Info.plist``` to fake a device when you don't have a hardware node. The app will act like it has a MapTheThings node to talk to. Set it to a bigger number to debug behavior when there are more nodes around.
- Test Host - Use a test host server by setting TestHost="localhost:3000" in ```Info.plist```.
- Enable Fabric by defining FABRIC_API_KEY=xyz and FABRIC_BUILD_SECRET=abc in ```private.env```.

## People
- [Frank](@frankleonrose) - Focused on working example of Active Collection. Bluetooth communication. Sync GPS samples with server.
- [Forrest](@forrestfiller) - Putting burgeoning Swift skills to work.
- @masterswift - Messaging UI.

## Thanks
Forrest would like to thank
 - Jordan @CocoaPods with MKCoordinateSpanMake and re-centering
 - Mike @Cocoapods with formatting floats

## License
Source code for Map The Things is released under the MIT License,
which can be found in the [LICENSE](LICENSE) file.
