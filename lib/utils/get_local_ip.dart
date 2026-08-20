
import 'dart:io';

import 'package:flutter/foundation.dart';

Future<String?> getWifiIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );

    // Common Wi-Fi interface names
    final wifiNames = ['wlan0', 'en0', 'eth0'];

    for (var name in wifiNames) {
      final interface = interfaces.firstWhere(
        (i) => i.name == name,
        orElse: () => interfaces.first,
      );

      if (interface.addresses.isNotEmpty) {
        final ip = interface.addresses.firstWhere(
          (addr) => !addr.isLoopback,
          orElse: () => interface.addresses.first,
        );
        return ip.address;
      }
    }
    return null;
  } catch (e) {
    if (kDebugMode) {
      print('Error getting Wi-Fi IP: $e');
    }
    return null;
  }
}
