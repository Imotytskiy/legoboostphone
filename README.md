# legoboostphone

iPhone face and camera prototype for a LEGO BOOST robot.

## Current Implementation

- Landscape SwiftUI robot face with circular cyan eyes, nose, and orange animated eyebrows.
- Five selectable emotions and automatic blinking; camera and streaming settings in a separate sheet.
- Front-camera face detection using Apple Vision.
- LEFT / CENTER / RIGHT position indicator.
- Optional camera-frame transmission to a Python receiver on a Mac.
- Receiver access protected by a random token generated at startup.

The browser-based iPhone application, WebRTC, sensor telemetry, and motor
integration are planned; they are not implemented in this repository yet.
Existing Python/BLE and DualSense control code is not included.

## iPhone

Open `LegoRobot.xcodeproj` in Xcode. Select your own development team under
Signing & Capabilities and select a physical iPhone. Enable Developer Mode
and trust your developer certificate when prompted, then run the app.
Camera capture requires a physical device.

## Mac Camera Viewer

Run with Python 3 (no third-party packages required):

```sh
python3 mac_camera.py
```

Open the localhost URL printed by the receiver. On the iPhone, enter that
same URL with `localhost` replaced by the Mac's local IP address, retaining
the token query parameter, and enable **Mac camera**. Allow Local Network
access. Both devices must be on the same trusted local network.

Frames remain in memory and expire from the viewer after five seconds
without updates. The receiver uses HTTP, not encryption; do not expose
port 8765 to the internet. The access token changes whenever it restarts.

## Project Status

The simulator build has passed. Real-device streaming and orientation
still require end-to-end validation. This prototype does not control motors.

## Continue on Another Mac

Clone this repository, or run `git pull --ff-only` in an existing checkout.
Open `LegoRobot.xcodeproj`, select your development team and physical iPhone,
then run. The current face uses landscape-right orientation. The approved
visual reference is `design/robot-face-landscape-v1.png`.

Next checks: validate eyebrow emotions and blinking on the phone, verify
landscape camera orientation and LEFT/RIGHT, then test streaming to the Mac.
Motor integration requires the existing Python/BLE and DualSense sources,
which are not in this repository. The head motor is on port `0x02`.

Unofficial hobby project; not affiliated with the LEGO Group.
