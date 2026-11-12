import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Starts Firebase once, before the app is shown.
///
/// When Firebase is not configured (or in tests), [isReady] stays false and
/// every module keeps working with in-memory data only.
class FirebaseSetup {
  FirebaseSetup._();

  static bool isReady = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isReady = true;
    } catch (error) {
      debugPrint('Firebase not available, using in-memory data: $error');
    }
  }
}
