import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/auth/data/auth_repository.dart';
import 'package:foodsaver/features/home/presentation/home_screen.dart';
import 'package:foodsaver/features/profile/data/user_profile_repository.dart';

void main() {
  late AuthRepository auth;
  late UserProfileRepository profiles;

  setUp(() {
    auth = AuthRepository();
    profiles = UserProfileRepository(
      auth: auth,
      clock: () => DateTime(2026, 11, 1),
    );
  });

  Widget home() => MaterialApp(
    home: FoodSaverHomePage(profiles: profiles, auth: auth),
  );

  Finder greeting() => find.byKey(const ValueKey('home-greeting-name'));

  testWidgets('greets the signed-in user by name, not a placeholder', (
    tester,
  ) async {
    await auth.signUp(
      displayName: 'Sami Trabelsi',
      email: 'sami@example.com',
      password: 'secret12',
    );
    await tester.pumpWidget(home());

    expect(tester.widget<Text>(greeting()).data, 'Sami Trabelsi');
    expect(find.text('Maya'), findsNothing);
  });

  testWidgets('shows the new name after the profile is edited', (tester) async {
    await auth.signUp(
      displayName: 'Sami',
      email: 'sami@example.com',
      password: 'secret12',
    );
    await tester.pumpWidget(home());

    await profiles.updateDisplayName('Sami T.');
    await tester.pump();

    expect(tester.widget<Text>(greeting()).data, 'Sami T.');
  });

  testWidgets('falls back to a neutral name when nobody is signed in', (
    tester,
  ) async {
    await tester.pumpWidget(home());

    expect(tester.widget<Text>(greeting()).data, 'Food saver');
  });
}
