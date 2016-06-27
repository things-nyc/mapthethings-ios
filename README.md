# MapTheThings-iOS

The iOS app portion of [MapTheThings](http://map.thethings.nyc), the
global coverage map for The Things Network (TTN).

## Client Responsibilities
- Authenticate via OAuth2 with identity providers of the user's choice: Github, Google, Facebook, Twitter. Securely store authentication token if requested by user.

- View mode - Show MapTheThings map of local area. This could be simple a WebView looking at map.thethings.nyc.

- Settings - Set the ID of the device to listen to in MQTT Collection mode.

- Collect mode view - Show current lat/lon in text and on map. Show time since last successful TTN packet transmission and time since most recent attempt (if known). Show RSSI and SNR of last successful packet. Select collection mode. Show appropriate status from server that data is being collected.

## Collection Modes
- Active Collect mode - App connects to node and drives transmission. App directs node to transmit current lat/lon. App records each transmission and periodically sends list of attempts to the API. Server then reconciles with packets it has received from TTN. In this mode we are certain when an attempt was made and not successfully sent through TTN, so we can report packet loss.

- Matching Collect mode - (the Chris Merck method) App posts periodic GPS samples which are then time-aligned with packets sent by passive node.
There is a node in the same location as the iOS device running the app. The node transmits packets periodically. The app collects periodic GPS samples. The app sends the GPS samples to the API. The server then aligns GPS samples with TTN packets to determine where the user was then the TTN packet was sent.

- Listener Collect mode - App subscribes to MQTT and posts on packet received.
There is a node in the same location as the iOS device running the app. The node transmits packets periodically. The app is subscribed to MQTT and when it receives a packet from the device, it posts the packet data and lat/lon to the API. This is how ttnmapper.org collects info.

## People
- Frank - Focused on working example of Active Collection. Bluetooth communication. Sync GPS samples with server.
- ???

## License
Source code for Map The Things is released under the MIT License,
which can be found in the [LICENSE](LICENSE) file.
