# Connect IQ Store listing

Upload: `bin/ESkate.iq` (build: `monkeyc -e -r -f monkey.jungle -o bin/ESkate.iq -y developer_key.der`).
Icon: `store/icon.png` (500×500). Screenshots: `docs/*.png`.

## App name

E-Skate

## Type / category

Watch App → Fitness / Sports

## Short description

Record electric skateboard rides as their own activity.

## Description

A dedicated activity for electric skateboard rides, so you don't have to record them as "Inline Skating" or "E-Bike".

Looks and works like the watch's built-in activities:
- Pre-start page with GPS status, beep and buzz when GPS is ready
- Two configurable data screens (4 fields each): distance, timer, speed, max / average speed, heart rate, ascent, calories, watch battery, time of day
- Map page with your track (watches with maps)
- Native pause menu: Resume / Save / Discard
- Speed alert (vibration) at a speed you choose
- km/h or mph from your watch settings
- Light or dark background
- Screen taps are ignored while riding, so a fall or a glove can't stop the ride

Rides are saved to Garmin Connect with GPS track, speed, distance and heart rate. They appear as "Other" named "E-Skate"; you can change the type in Garmin Connect.

Settings: hold UP (MENU) on the watch, or in Garmin Connect → device → Activities & Apps → E-Skate → Settings.

Coming later: board battery and voltage over Bluetooth (Exway boards).

Open source: https://github.com/RomanZubriychuk/garmin-eskate

## What's new (1.0)

First release.

## Permissions (for the reviewer)

- Positioning: GPS track, speed and distance.
- Fit / FitContributor: saving the ride to Garmin Connect.
- BluetoothLowEnergy: board connection, prepared but switched off in this version (no scanning happens).
