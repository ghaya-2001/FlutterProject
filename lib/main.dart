export 'app.dart';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/firebase/firebase_setup.dart';
import 'features/fridge/data/fridge_repository.dart';
import 'features/notifications/data/notification_repository.dart';
import 'features/notifications/data/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firestore (shopping lists, donations, notifications). Must be ready
  // before the repositories are first used. Falls back to in-memory data.
  await FirebaseSetup.init();

  // Phone notifications: expiry alerts (7 days, 3 days, same day) and
  // donation requests. Started without waiting so the app opens right away.
  NotificationRepository.instance.pushHandler =
      NotificationService.instance.showNow;
  NotificationService.instance.init(FridgeRepository.instance);

  runApp(const FoodSaverApp());
}
