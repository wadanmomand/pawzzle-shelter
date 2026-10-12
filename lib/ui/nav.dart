/// Navigation helpers (kept here to avoid import cycles via main.dart).
library;

import 'package:flutter/material.dart';
import 'package:shelter/ui/hub_screen.dart';
import 'package:shelter/ui/settings_screen.dart';

void openSettings(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  );
}

void openHub(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const HubScreen()),
  );
}
