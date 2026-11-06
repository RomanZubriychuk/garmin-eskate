import Toybox.Application;
import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.WatchUi;

// Bluetooth LE link to the board.
//
// Exway does not publish its BLE protocol. This class finds the board by
// name, connects, subscribes to notifications on the most common
// "serial over BLE" services and hands every packet to BoardProtocol.
// Discovered services and the last raw packet are shown on the
// diagnostics page so the real protocol can be worked out.
class BoardLink extends BluetoothLowEnergy.BleDelegate {
    enum {
        STATE_OFF,
        STATE_SCANNING,
        STATE_CONNECTING,
        STATE_CONNECTED
    }

    // Candidate [service, notify characteristic] pairs (max 3 profiles in CIQ).
    const CANDIDATES = [
        ["0000FFE0-0000-1000-8000-00805F9B34FB", "0000FFE1-0000-1000-8000-00805F9B34FB"], // HM-10 style UART
        ["6E400001-B5A3-F393-E0A9-E50E24DCCA9E", "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"], // Nordic UART
        ["0000FFF0-0000-1000-8000-00805F9B34FB", "0000FFF4-0000-1000-8000-00805F9B34FB"]  // generic FFF0
    ];

    var state as Number = STATE_OFF;
    var deviceName as String? = null;
    var rssi as Number? = null;
    var battery as Number? = null;          // %
    var voltage as Float? = null;           // V
    var packets as Number = 0;
    var lastPacketHex as String = "";
    var services as Array<String> = [] as Array<String>;

    private var _device as BluetoothLowEnergy.Device?;
    private var _nextProfile as Number = 0;
    private var _nameFilter as String = "exway";

    function initialize() {
        BleDelegate.initialize();
    }

    function start() as Void {
        var f = Application.Properties.getValue("boardNameFilter");
        if (f instanceof String && f.length() > 0) {
            _nameFilter = f.toLower();
        }
        BluetoothLowEnergy.setDelegate(self);
        _nextProfile = 0;
        registerNextProfile();
    }

    function stop() as Void {
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
        var d = _device;
        if (d != null) {
            BluetoothLowEnergy.unpairDevice(d);
            _device = null;
        }
        state = STATE_OFF;
    }

    // ---- profile registration (sequential) ----
    private function registerNextProfile() as Void {
        if (_nextProfile >= CANDIDATES.size()) {
            startScan();
            return;
        }
        var c = CANDIDATES[_nextProfile];
        try {
            BluetoothLowEnergy.registerProfile({
                :uuid => BluetoothLowEnergy.stringToUuid(c[0]),
                :characteristics => [{
                    :uuid => BluetoothLowEnergy.stringToUuid(c[1]),
                    :descriptors => [BluetoothLowEnergy.cccdUuid()]
                }]
            });
        } catch (e) {
            _nextProfile++;
            registerNextProfile();
        }
    }

    function onProfileRegister(uuid as BluetoothLowEnergy.Uuid, status as BluetoothLowEnergy.Status) as Void {
        _nextProfile++;
        registerNextProfile();
    }

    private function startScan() as Void {
        state = STATE_SCANNING;
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
        WatchUi.requestUpdate();
    }

    // ---- scanning ----
    function onScanResults(scanResults as BluetoothLowEnergy.Iterator) as Void {
        if (state != STATE_SCANNING) {
            return;
        }
        for (var r = scanResults.next() as BluetoothLowEnergy.ScanResult?; r != null;
             r = scanResults.next() as BluetoothLowEnergy.ScanResult?) {
            var name = r.getDeviceName();
            if (name != null && name.toLower().find(_nameFilter) != null) {
                deviceName = name;
                rssi = r.getRssi();
                BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
                state = STATE_CONNECTING;
                _device = BluetoothLowEnergy.pairDevice(r);
                WatchUi.requestUpdate();
                return;
            }
        }
    }

    // ---- connection ----
    function onConnectedStateChanged(device as BluetoothLowEnergy.Device,
                                     connState as BluetoothLowEnergy.ConnectionState) as Void {
        if (connState == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            state = STATE_CONNECTED;
            collectServices(device);
            subscribe(device);
        } else {
            // The paired device reconnects automatically when back in range.
            state = STATE_CONNECTING;
        }
        WatchUi.requestUpdate();
    }

    private function collectServices(device as BluetoothLowEnergy.Device) as Void {
        services = [] as Array<String>;
        var it = device.getServices();
        for (var s = it.next() as BluetoothLowEnergy.Service?; s != null;
             s = it.next() as BluetoothLowEnergy.Service?) {
            services.add(s.getUuid().toString());
        }
    }

    private function subscribe(device as BluetoothLowEnergy.Device) as Void {
        for (var i = 0; i < CANDIDATES.size(); i++) {
            var svc = device.getService(BluetoothLowEnergy.stringToUuid(CANDIDATES[i][0]));
            if (svc == null) { continue; }
            var ch = svc.getCharacteristic(BluetoothLowEnergy.stringToUuid(CANDIDATES[i][1]));
            if (ch == null) { continue; }
            var cccd = ch.getDescriptor(BluetoothLowEnergy.cccdUuid());
            if (cccd != null) {
                try {
                    cccd.requestWrite([0x01, 0x00]b);
                } catch (e) {
                    // Only one GATT request may be pending; ignore and keep the first.
                }
                return;
            }
        }
    }

    // ---- data ----
    function onCharacteristicChanged(ch as BluetoothLowEnergy.Characteristic, value as ByteArray) as Void {
        packets++;
        lastPacketHex = toHex(value);
        BoardProtocol.parse(value, self);
        var b = battery;
        if (b != null) {
            getApp().ride.setBoardBattery(b);
        }
        WatchUi.requestUpdate();
    }

    private function toHex(bytes as ByteArray) as String {
        var s = "";
        var n = bytes.size() < 20 ? bytes.size() : 20;
        for (var i = 0; i < n; i++) {
            s += bytes[i].format("%02X");
            if (i % 2 == 1) { s += " "; }
        }
        return s;
    }
}
