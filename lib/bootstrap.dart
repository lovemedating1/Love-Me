import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/notifications/fcm_service.dart';
import 'firebase_options.dart';

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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);
  await FcmService.instance.init();

  // Later tracks will add here: payment SDK init.

  runApp(const ProviderScope(child: LoveMeApp()));
}
