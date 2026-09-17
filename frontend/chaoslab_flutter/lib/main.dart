import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env is optional — ApiConstants.baseUrl falls back to
  // http://127.0.0.1:8000 if it's missing, so a fresh checkout still runs
  // without extra setup (see .env.example for what to copy).
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // No .env present — fall back silently, ApiConstants handles the default.
  }

  runApp(const ChaosLabApp());
}
