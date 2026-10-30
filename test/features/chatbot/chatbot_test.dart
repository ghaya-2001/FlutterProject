import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/chatbot/domain/chatbot_engine.dart';
import 'package:foodsaver/features/chatbot/presentation/chatbot_screen.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/list/data/shopping_list_repository.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late ChatbotEngine engine;

  setUp(() {
    final fridge = FridgeRepository(clock: () => today);
    engine = ChatbotEngine(
      fridge: fridge,
      shopping: ShoppingListRepository(),
      donations: DonationRepository(fridge: fridge, seed: false),
    );
  });

  test('understands typed questions with keywords', () {
    expect(engine.topicFor('What expires soon?'), ChatbotTopic.expiringSoon);
    expect(engine.topicFor('what should I buy'), ChatbotTopic.shopping);
    expect(engine.topicFor('How to donate?'), ChatbotTopic.donate);
    expect(
      engine.topicFor('Comment marchent les alertes ?'),
      ChatbotTopic.notifications,
    );
    expect(engine.topicFor("I don't know"), isNull);
  });

  test('expiring soon answer uses the fridge data', () {
    final reply = engine.answer(ChatbotTopic.expiringSoon);
    expect(reply.text, contains('Yogurt – Today'));
    expect(reply.text, isNot(contains('Eggs')));
    expect(reply.link, ChatbotLink.expiringSoon);
  });

  test('unknown questions get a fallback answer', () {
    expect(engine.answerText('blabla').text, startsWith('Sorry'));
  });

  testWidgets('tapping a predefined question shows the answer', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ChatbotScreen(engine: engine)));

    expect(find.textContaining('Food Saver assistant'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('chatbot-question-notifications')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('7 days before, 3 days before'), findsOneWidget);
    expect(find.text('Open notifications'), findsOneWidget);
  });
}
