import '../../donations/data/donation_repository.dart';
import '../../expiry/domain/expiry_alerts.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../../list/data/shopping_list_repository.dart';

enum ChatbotTopic { expiringSoon, shopping, donate, notifications, help }

/// Screen the chatbot can open from an answer.
enum ChatbotLink { expiringSoon, shoppingList, donations, notifications }

class ChatbotQuestion {
  const ChatbotQuestion(this.topic, this.label);

  final ChatbotTopic topic;
  final String label;
}

class ChatbotReply {
  const ChatbotReply(this.text, {this.link, this.linkLabel});

  final String text;
  final ChatbotLink? link;
  final String? linkLabel;
}

/// Questions shown as buttons in the chat.
const chatbotQuestions = <ChatbotQuestion>[
  ChatbotQuestion(
    ChatbotTopic.expiringSoon,
    'Which food products are expiring soon?',
  ),
  ChatbotQuestion(ChatbotTopic.shopping, 'What should I buy?'),
  ChatbotQuestion(ChatbotTopic.donate, 'How can I donate food?'),
  ChatbotQuestion(ChatbotTopic.notifications, 'How do notifications work?'),
  ChatbotQuestion(ChatbotTopic.help, 'What can you do?'),
];

/// Keywords (English and French) used to understand typed questions.
const _keywords = <ChatbotTopic, List<String>>{
  ChatbotTopic.expiringSoon: [
    'expir',
    'expire',
    'soon',
    'old',
    'périm',
    'perim',
    'date',
  ],
  ChatbotTopic.shopping: [
    'buy',
    'shop',
    'list',
    'grocer',
    'course',
    'acheter',
    'achat',
  ],
  ChatbotTopic.donate: [
    'donat',
    'donate',
    'give',
    'charity',
    'restaurant',
    'donner',
    'association',
  ],
  ChatbotTopic.notifications: ['notif', 'alert', 'remind', 'rappel', 'alerte'],
  ChatbotTopic.help: ['help', 'hello', 'hi', 'aide', 'bonjour', 'salut'],
};

/// Rule-based assistant: predefined questions and answers, some of them
/// filled in with the user's own data. No AI service is used.
class ChatbotEngine {
  ChatbotEngine({
    FridgeRepository? fridge,
    ShoppingListRepository? shopping,
    DonationRepository? donations,
  }) : _fridge = fridge ?? FridgeRepository.instance,
       _shopping = shopping ?? ShoppingListRepository.instance,
       _donations = donations ?? DonationRepository.instance;

  final FridgeRepository _fridge;
  final ShoppingListRepository _shopping;
  final DonationRepository _donations;

  static const welcome = ChatbotReply(
    'Hi! I\'m the Food Saver assistant. Pick a question below or type '
    'your own.',
  );

  /// Finds the topic of a typed question, or null when nothing matches.
  ChatbotTopic? topicFor(String text) {
    final normalized = text.toLowerCase();
    // Checked in order, so "donate expiring food" goes to donations.
    for (final topic in [
      ChatbotTopic.donate,
      ChatbotTopic.notifications,
      ChatbotTopic.shopping,
      ChatbotTopic.expiringSoon,
      ChatbotTopic.help,
    ]) {
      for (final keyword in _keywords[topic]!) {
        if (RegExp('\\b$keyword').hasMatch(normalized)) {
          return topic;
        }
      }
    }
    return null;
  }

  ChatbotReply answerText(String text) {
    final topic = topicFor(text);
    if (topic == null) {
      return const ChatbotReply(
        'Sorry, I didn\'t understand. I can help with expiring food, your '
        'shopping list, donations and notifications. Try one of the '
        'questions below.',
      );
    }
    return answer(topic);
  }

  ChatbotReply answer(ChatbotTopic topic) {
    switch (topic) {
      case ChatbotTopic.expiringSoon:
        return _expiringSoon();
      case ChatbotTopic.shopping:
        return _shoppingAnswer();
      case ChatbotTopic.donate:
        return _donateAnswer();
      case ChatbotTopic.notifications:
        return const ChatbotReply(
          'Food Saver checks the expiry date of every food in your fridge. '
          'You get an alert 7 days before, 3 days before and on the expiry '
          'day, at 9:00. You also get a notification when a restaurant or a '
          'charity asks for one of your donations. All alerts are listed on '
          'the Notifications screen (bell icon on Home).',
          link: ChatbotLink.notifications,
          linkLabel: 'Open notifications',
        );
      case ChatbotTopic.help:
        return const ChatbotReply(
          'I can tell you which foods expire soon, what to buy, how to '
          'donate food and how alerts work. Just tap a question!',
        );
    }
  }

  ChatbotReply _expiringSoon() {
    final now = _fridge.now;
    final soon = expiringSoon(_fridge.items, now);
    final expired = _fridge.items.where((item) => item.isExpired(now)).length;
    if (soon.isEmpty) {
      return ChatbotReply(
        expired == 0
            ? 'Good news: nothing in your fridge expires in the next 7 days.'
            : 'Nothing expires in the next 7 days, but $expired '
                  '${expired == 1 ? 'food has' : 'foods have'} already '
                  'expired. Check your fridge.',
      );
    }
    final lines = soon
        .take(5)
        .map((item) => '• ${item.name} – ${daysLeftLabel(item, now)}')
        .join('\n');
    final more = soon.length > 5 ? '\n…and ${soon.length - 5} more.' : '';
    return ChatbotReply(
      'These foods expire within 7 days:\n$lines$more\n\n'
      'Eat them first, or donate them if you can\'t.',
      link: ChatbotLink.expiringSoon,
      linkLabel: 'See expiring soon',
    );
  }

  ChatbotReply _shoppingAnswer() {
    final list = _shopping.selectedList;
    final pending = list?.pendingItems ?? const [];
    final now = _fridge.now;
    final expired = _fridge.items
        .where((item) => item.isExpired(now))
        .map((item) => item.name)
        .toList();

    final buffer = StringBuffer();
    if (pending.isEmpty) {
      buffer.write('Your shopping list is empty.');
    } else {
      buffer.write('Still to buy in "${list!.name}":\n');
      buffer.write(
        pending
            .take(6)
            .map((item) => '• ${item.name} (${item.quantityLabel})')
            .join('\n'),
      );
      if (pending.length > 6) {
        buffer.write('\n…and ${pending.length - 6} more.');
      }
    }
    if (expired.isNotEmpty) {
      buffer.write(
        '\n\nThese foods expired and may need replacing: '
        '${expired.join(', ')}.',
      );
    }
    buffer.write('\n\nTip: check your fridge first so you don\'t buy twice.');
    return ChatbotReply(
      buffer.toString(),
      link: ChatbotLink.shoppingList,
      linkLabel: 'Open shopping list',
    );
  }

  ChatbotReply _donateAnswer() {
    final suggested = _donations.suggestedFoods.length;
    final hint = suggested == 0
        ? ''
        : '\n\nRight now, $suggested '
              '${suggested == 1 ? 'food expires' : 'foods expire'} within '
              '7 days and could be donated.';
    return ChatbotReply(
      'To donate food:\n'
      '1. Open Donations and tap "New donation" (or "Donate" on a food).\n'
      '2. Choose the food from your fridge, the quantity and the '
      'consume-before date.\n'
      '3. Partner restaurants and charities can then request it.\n'
      '4. Accept or refuse each request. Once picked up, mark it as '
      'collected.$hint',
      link: ChatbotLink.donations,
      linkLabel: 'Open donations',
    );
  }
}
