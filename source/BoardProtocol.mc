import Toybox.Lang;

// Decoder for packets coming from the board.
//
// The Exway Atlas Pro protocol is not public, so nothing is decoded yet:
// battery/voltage stay "--" and the watch shows raw packets on the
// diagnostics page. Once the packet format is known (e.g. from an
// Android "Bluetooth HCI snoop log" of the official Exway app), fill in
// parse() below and set link.battery / link.voltage.
module BoardProtocol {
    function parse(packet as ByteArray, link as BoardLink) as Void {
        // Example of what a decoder will look like once the format is known:
        //
        // if (packet.size() >= 6 && packet[0] == 0xAA && packet[1] == 0x01) {
        //     link.battery = packet[4];
        //     link.voltage = ((packet[2] << 8) | packet[3]) / 100.0;
        // }
    }
}
