import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';

/// App bootstrap: one-time init before the widget tree is built.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(
    SupabaseConfig.url.isNotEmpty && SupabaseConfig.anonKey.isNotEmpty,
    'Missing --dart-define=SUPABASE_URL / SUPABASE_ANON_KEY (see .vscode/launch.json).',
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  // Later tracks will add here: Firebase.initializeApp() (fcm_tokens),
  // geolocator setup, payment SDK init.

  runApp(const ProviderScope(child: LoveMeApp()));
}
