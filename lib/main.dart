/// Titik masuk aplikasi Hadir.
library;

import 'package:flutter/material.dart';

import 'package:hadir/app.dart';
import 'package:hadir/state/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.init();
  runApp(HadirApp(bootstrap: bootstrap));
}
