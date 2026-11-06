# E-Skate — Connect IQ app for electric skateboards (Garmin watches)

A dedicated activity for riding an electric skateboard (built for the Exway Atlas Pro),
so you don't have to record rides as "Inline Skating" or "E-Bike".

## Features

The Exway remote already shows speed and board battery, so the watch focuses on what
the remote doesn't: recording the ride, distance, ride time and heart rate.

| Screen | Default contents |
|---|---|
| 1. Data screen 1 | **distance** (large), ride time, heart rate, speed |
| 2. Data screen 2 | **speed** (large), board battery, distance, max speed |
| 3. Board | Bluetooth status, board name, battery, voltage (only when the board link is on) |
| 4. Diagnostics | RSSI, discovered BLE services, raw packets (only when the board link is on) |

- Records the ride to FIT (GPS track, speed, distance, heart rate, laps) → syncs to Garmin Connect.
- Vibration alert when exceeding a configurable speed (setting, 0 = off); speed turns red.
- km/h or mph, following the watch's unit settings.
- Touch input is ignored so a ride can't be stopped accidentally.

### Configurable data fields

Each data screen has 4 slots — main (large), left, right, bottom. Any slot can show:
distance, ride time, heart rate, speed, max speed, average speed, board battery,
board voltage, watch battery, time of day, calories, ascent — or nothing.
Screen 2 is skipped when all its slots are empty.

Change them either:
- **on the watch**: hold UP (MENU) → *Data fields*, or
- **on the phone**: Garmin Connect → device → Activities & Apps → E-Skate → Settings.

### Buttons

| Button | Action |
|---|---|
| START | start / pause (when paused: "Resume / Save / Discard" menu) |
| BACK | new lap while recording; exit when not recording |
| UP / DOWN | switch screens (swipe up / down on watches without these buttons) |
| hold UP (MENU) | data field settings |

## Battery use

- The screen is redrawn once per second — not on every GPS fix or Bluetooth packet.
- Settings are cached in memory and reread only when they change.
- The board link is **off by default**: until the Exway protocol is decoded it gives no
  useful data, and Bluetooth scanning is the biggest drain after GPS.
- When the board link is on, the board is searched in 30 s windows with 90 s pauses
  instead of scanning continuously.
- GPS uses the watch's default (single-band) mode.

## Connecting to the Exway board — important

No pairing in the watch's Sensors menu is needed (it only supports standard sensors).
Turn on **Connect to board** (hold UP → *Data fields*, or in Garmin Connect settings);
the app then finds the board by name and connects by itself.

Exway does not publish its Bluetooth protocol. The app already finds the board by name
(by default, the name contains `Exway`), connects, and subscribes to notifications on common
"UART-over-BLE" services (`FFE0/FFE1`, Nordic UART, `FFF0/FFF4`), but **packet decoding is
not implemented yet** — battery shows `--`, and the Diagnostics screen shows the raw data.
There is no board control (throttle/brake), and there won't be — it's unsafe.

To add battery/voltage/speed from the controller, a protocol capture is needed:

1. Android → Developer options → enable **Bluetooth HCI snoop log**.
2. Ride/connect with the official Exway app for a couple of minutes,
   noting the battery percentage shown.
3. Export the log (`adb bugreport`) or capture data with **nRF Connect**
   (service and characteristic UUIDs + sample packets).
4. Implement the format in `source/BoardProtocol.mc` (a stub is there).

Note: the watch and the phone usually can't both hold a connection to the board —
close the Exway app on your phone while riding.

## Supported watches

Any Garmin watch with Connect IQ API 3.1+ and Bluetooth LE support for apps.
The manifest currently lists:

- **fēnix** 6 / 6S / 6X Pro, 7 / 7S / 7X (incl. Pro), 8 (43/47 mm, Solar 47/51 mm), fēnix E
- **epix** (Gen 2), epix Pro (42/47/51 mm)
- **Enduro**, Enduro 2, Enduro 3
- **MARQ** (Gen 2), MARQ Aviator (Gen 2)
- **Forerunner** 165, 245, 255, 265, 745, 945 / 945 LTE, 955, 965 (incl. Music / S variants)
- **Venu** 2 / 2S / 2 Plus, Venu 3 / 3S, Venu Sq 2, Venu X1
- **vívoactive** 4 / 4S, vívoactive 5
- **Instinct** 2 / 2S / 2X, Instinct Crossover, Instinct 3 (AMOLED 45/50 mm, Solar 45 mm)

The screens use relative positions and font-based spacing, so they adapt to round,
rectangular, AMOLED and MIP displays. To add a model, add its device ID to `manifest.xml`
(or use VS Code → `Monkey C: Edit Products`). If the compiler rejects an ID, or reports
that `BluetoothLowEnergy` is not available on a device, remove that device from the list.

## Build and install

1. Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (SDK Manager)
   and the Monkey C extension for VS Code.
2. Generate a developer key: VS Code → `Monkey C: Generate a Developer Key`.
3. Build for your model (replace `fenix847mm` with your device ID from `manifest.xml`):
   ```bash
   monkeyc -f monkey.jungle -d fenix847mm -o bin/ESkate.prg -y developer_key.der
   ```
   To build a package for all listed watches (e.g. for the Connect IQ Store):
   ```bash
   monkeyc -e -f monkey.jungle -o bin/ESkate.iq -y developer_key.der
   ```
4. Test in the simulator: `connectiq`, then `monkeydo bin/ESkate.prg fenix847mm`.
5. Connect the watch via USB and copy `ESkate.prg` to `GARMIN/APPS/`.

In Garmin Connect the activity is saved as "Other" with the name "E-Skate"
(Connect IQ has no dedicated skateboarding sport type); you can rename it
or change its type in Garmin Connect.

## Structure

```
manifest.xml             supported watches, permissions (GPS, FIT, BLE)
source/ESkateApp.mc      entry point, GPS
source/RideSession.mc    activity recording, vibration alerts
source/BoardLink.mc      board discovery and BLE connection
source/BoardProtocol.mc  board packet decoding (stub)
source/ESkateView.mc     screens
source/Fields.mc         data field definitions and formatting
source/Config.mc         data screen layout stored in settings
source/FieldsMenu.mc     on-watch data field settings menu
source/ESkateDelegate.mc buttons and stop menu
```
