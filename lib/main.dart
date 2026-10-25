import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppDependencies dependencies = await AppDependencies.create();
  runApp(BillScannerApp(dependencies: dependencies));
}
