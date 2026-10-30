import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Id of the user whose data is read and written in Firestore.
///
/// TODO(auth): there is no Firebase Authentication yet (Membre 1). Once it
/// exists, replace this with `FirebaseAuth.instance.currentUser!.uid`.
const currentUserId = 'demo-user';

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
