// Demo data for the fridge and the donation goals (Membre 2).
//
// Creates (or reuses) five demo accounts in the Firebase project, fills the
// donor's fridge and publishes donation goals with some progress, so the
// scenario of the presentation can be played on two phones:
//
//   dart run tool/seed_demo_goals.dart            (password: Demo2026)
//   dart run tool/seed_demo_goals.dart MyPass123  (another password)
//
// Run it again the day before the demo: every date (expiry dates, deadlines,
// gifts) is computed from today, and the goals are written again from zero.
// It only uses the public REST APIs with the accounts' own sign-in, so it
// works with the open development rules and with firestore.rules.
import 'dart:convert';
import 'dart:io';

const _project = 'foodsaver-83ca2';
const _documents =
    'https://firestore.googleapis.com/v1/projects/$_project/databases/(default)/documents';

class DemoAccount {
  const DemoAccount(
    this.key,
    this.email,
    this.name, {
    this.role = 'user',
    this.businessName = '',
  });

  final String key;
  final String email;
  final String name;
  final String role;
  final String businessName;
}

const accounts = [
  DemoAccount('khaoula', 'khaoula.demo@example.com', 'Khaoula'),
  DemoAccount(
    'charity',
    'maintendue.demo@example.com',
    'Main Tendue',
    role: 'restaurant',
    businessName: 'Association Main Tendue',
  ),
  DemoAccount(
    'jardin',
    'jardin.demo@example.com',
    'Le Jardin',
    role: 'restaurant',
    businessName: 'Le Jardin Solidaire',
  ),
  DemoAccount('sami', 'sami.demo@example.com', 'Sami'),
  DemoAccount('lina', 'lina.demo@example.com', 'Lina'),
];

late final String _apiKey;
final _http = HttpClient();
final _today = DateTime.now();
DateTime _day(int offset) =>
    DateTime(_today.year, _today.month, _today.day).add(Duration(days: offset));
DateTime _hoursAgo(int hours) => _today.subtract(Duration(hours: hours));

Future<void> main(List<String> args) async {
  final password = args.isEmpty ? 'Demo2026' : args.first;
  _apiKey = _readApiKey();

  final session = <String, ({String uid, String token})>{};
  for (final account in accounts) {
    session[account.key] = await _signIn(account, password);
    await _saveProfile(account, session[account.key]!);
    stdout.writeln('✓ ${account.email} (${account.role})');
  }

  await _fillFridge(session['khaoula']!);
  stdout.writeln('✓ fridge and history of Khaoula');

  await _publishGoals(session);
  stdout.writeln('✓ donation goals and gifts');

  stdout
    ..writeln()
    ..writeln('Demo accounts (password: $password):')
    ..writeln('  user (fridge + gives)  khaoula.demo@example.com')
    ..writeln('  charity (goals)        maintendue.demo@example.com')
    ..writeln('  restaurant (goals)     jardin.demo@example.com');
  _http.close();
}

// -----------------------------------------------------------------------------
// Data
// -----------------------------------------------------------------------------

Future<void> _fillFridge(({String uid, String token}) user) async {
  final base = 'users/${user.uid}';
  Map<String, Object?> food(
    String name,
    String category,
    double quantity,
    String unit,
    int daysLeft, {
    int addedDaysAgo = 2,
    String note = '',
  }) => {
    'name': name,
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'expiryDate': _day(daysLeft),
    'addedAt': _today.subtract(Duration(days: addedDaysAgo)),
    'note': note,
  };

  final foods = {
    // Asked for by the goals: can be given from the fridge.
    'demo-milk': food('Milk', 'Dairy', 2, 'L', 2),
    'demo-rice': food('Basmati rice', 'Pantry', 3, 'kg', 120, addedDaysAgo: 9),
    'demo-tomatoes': food('Tomatoes', 'Vegetables', 1.5, 'kg', 3),
    'demo-eggs': food('Eggs', 'Dairy', 12, 'pcs', 10),
    // Expiry alerts, "use first" and the anti-waste statistics.
    'demo-yogurt': food('Yogurt', 'Dairy', 4, 'pcs', 0),
    'demo-spinach': food('Spinach', 'Vegetables', 1, 'pack', 1),
    'demo-chicken': food(
      'Chicken breast',
      'Meat & Fish',
      0.8,
      'kg',
      1,
      note: 'Cook first',
    ),
    'demo-bread': food('Bread', 'Bakery', 1, 'pcs', 1, addedDaysAgo: 1),
    'demo-apples': food('Apples', 'Fruits', 6, 'pcs', 6),
    'demo-juice': food('Orange juice', 'Beverages', 1, 'L', 8),
    'demo-peas': food('Frozen peas', 'Frozen', 1, 'kg', 60, addedDaysAgo: 20),
    'demo-cheese': food('Cheese', 'Dairy', 0.3, 'kg', -1, addedDaysAgo: 12),
  };

  Map<String, Object?> event(
    String type,
    String name,
    String category,
    double quantity,
    String unit,
    int daysAgo, {
    int? daysLeft,
    String? recipe,
  }) => {
    'type': type,
    'foodName': name,
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'at': _today.subtract(Duration(days: daysAgo, hours: 3)),
    'daysLeft': daysLeft,
    'recipe': recipe,
  };

  final history = {
    'demo-ev-1': event(
      'consumed',
      'Bananas',
      'Fruits',
      4,
      'pcs',
      1,
      daysLeft: 1,
    ),
    'demo-ev-2': event(
      'consumed',
      'Tomatoes',
      'Vegetables',
      0.5,
      'kg',
      1,
      daysLeft: 2,
      recipe: 'Shakshuka',
    ),
    'demo-ev-3': event(
      'consumed',
      'Eggs',
      'Dairy',
      4,
      'pcs',
      1,
      daysLeft: 8,
      recipe: 'Shakshuka',
    ),
    'demo-ev-4': event('consumed', 'Milk', 'Dairy', 1, 'L', 2, daysLeft: 0),
    'demo-ev-5': event(
      'consumed',
      'Zucchini',
      'Vegetables',
      0.6,
      'kg',
      3,
      daysLeft: 1,
    ),
    'demo-ev-6': event(
      'wasted',
      'Lettuce',
      'Vegetables',
      1,
      'pcs',
      4,
      daysLeft: -1,
    ),
    'demo-ev-7': event(
      'consumed',
      'Chicken thighs',
      'Meat & Fish',
      0.7,
      'kg',
      5,
      daysLeft: 1,
    ),
    'demo-ev-8': event('consumed', 'Yogurt', 'Dairy', 2, 'pcs', 6, daysLeft: 0),
    'demo-ev-9': event('consumed', 'Bread', 'Bakery', 1, 'pcs', 8, daysLeft: 1),
    'demo-ev-10': event(
      'wasted',
      'Strawberries',
      'Fruits',
      0.25,
      'kg',
      10,
      daysLeft: -2,
    ),
    'demo-ev-11': event(
      'consumed',
      'Pasta',
      'Pantry',
      1,
      'pack',
      11,
      daysLeft: 200,
    ),
    'demo-ev-12': event(
      'consumed',
      'Carrots',
      'Vegetables',
      0.5,
      'kg',
      13,
      daysLeft: 3,
    ),
  };

  await _commit(user.token, [
    for (final entry in foods.entries)
      _set('$base/fridge_items/${entry.key}', entry.value),
    for (final entry in history.entries)
      _set('$base/fridge_history/${entry.key}', entry.value),
    // The app must not add its own demo foods on top.
    _set(base, {'fridgeSeeded': true}, merge: true),
  ]);
}

Future<void> _publishGoals(
  Map<String, ({String uid, String token})> session,
) async {
  final charity = session['charity']!;
  final jardin = session['jardin']!;

  final goals = [
    (
      id: 'demo-goal-rice',
      owner: charity,
      name: 'Association Main Tendue',
      title: 'Rice for the soup kitchen',
      food: 'Rice',
      category: 'Pantry',
      target: 10.0,
      unit: 'kg',
      deadline: _day(6),
      description: 'We serve 80 hot meals every evening this week.',
      createdHoursAgo: 60,
      gifts: [('sami', 3.0, 40), ('lina', 2.5, 18)],
    ),
    (
      id: 'demo-goal-milk',
      owner: charity,
      name: 'Association Main Tendue',
      title: "Milk for the children's breakfast",
      food: 'Milk',
      category: 'Dairy',
      target: 12.0,
      unit: 'L',
      deadline: _day(2),
      description: '30 children come every morning before school.',
      createdHoursAgo: 30,
      gifts: [('sami', 6.0, 26), ('lina', 4.0, 5)],
    ),
    (
      id: 'demo-goal-pasta',
      owner: charity,
      name: 'Association Main Tendue',
      title: 'Pasta for the weekend meals',
      food: 'Pasta',
      category: 'Pantry',
      target: 8.0,
      unit: 'pack',
      deadline: null,
      description: '',
      createdHoursAgo: 140,
      gifts: [('sami', 3.0, 120), ('lina', 3.0, 96), ('sami', 2.0, 70)],
    ),
    (
      id: 'demo-goal-eggs',
      owner: jardin,
      name: 'Le Jardin Solidaire',
      title: 'Eggs for the Friday couscous',
      food: 'Eggs',
      category: 'Dairy',
      target: 60.0,
      unit: 'pcs',
      deadline: _day(4),
      description: 'A free couscous for the families of the neighbourhood.',
      createdHoursAgo: 20,
      gifts: [('lina', 12.0, 16), ('sami', 12.0, 3)],
    ),
    (
      id: 'demo-goal-tomatoes',
      owner: jardin,
      name: 'Le Jardin Solidaire',
      title: 'Tomatoes for the sauce',
      food: 'Tomatoes',
      category: 'Vegetables',
      target: 5.0,
      unit: 'kg',
      deadline: _day(3),
      description: '',
      createdHoursAgo: 8,
      gifts: [('sami', 1.0, 2)],
    ),
  ];

  for (final goal in goals) {
    final path = 'donation_goals/${goal.id}';
    // Start again from zero (ignored when the goal does not exist yet).
    await _commit(goal.owner.token, [
      {'delete': '$_root/$path'},
    ], quiet: true);
    await _commit(goal.owner.token, [
      _set(path, {
        'restaurantId': goal.owner.uid,
        'restaurantName': goal.name,
        'title': goal.title,
        'foodName': goal.food,
        'category': goal.category,
        'target': goal.target,
        'unit': goal.unit,
        'description': goal.description,
        'deadline': goal.deadline,
        'createdAt': _hoursAgo(goal.createdHoursAgo),
        'closed': false,
        'contributions': <Object?>[],
      }),
    ]);
    var n = 0;
    for (final (donor, quantity, hoursAgo) in goal.gifts) {
      final account = accounts.firstWhere((a) => a.key == donor);
      final user = session[donor]!;
      await _commit(user.token, [
        {
          'transform': {
            'document': '$_root/$path',
            'fieldTransforms': [
              {
                'fieldPath': 'contributions',
                'appendMissingElements': {
                  'values': [
                    _value({
                      'id': '${goal.id}-gift-${n++}',
                      'donorId': user.uid,
                      'donorName': account.name,
                      'quantity': quantity,
                      'createdAt': _hoursAgo(hoursAgo),
                      'fromFridge': true,
                    }),
                  ],
                },
              },
            ],
          },
        },
      ]);
    }
  }
}

// -----------------------------------------------------------------------------
// Firebase REST helpers
// -----------------------------------------------------------------------------

const _root = 'projects/$_project/databases/(default)/documents';

String _readApiKey() {
  final options = File('lib/firebase_options.dart').readAsStringSync();
  final match = RegExp(r"apiKey: '([^']+)'").firstMatch(options);
  if (match == null) {
    throw StateError('No apiKey in lib/firebase_options.dart');
  }
  return match.group(1)!;
}

/// Creates the account, or signs in when it already exists.
Future<({String uid, String token})> _signIn(
  DemoAccount account,
  String password,
) async {
  final body = {
    'email': account.email,
    'password': password,
    'returnSecureToken': true,
  };
  var result = await _post(
    'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey',
    body,
  );
  if (result.status != 200) {
    result = await _post(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'
      '?key=$_apiKey',
      body,
    );
  }
  if (result.status != 200) {
    throw StateError('Cannot sign in ${account.email}: ${result.body}');
  }
  final token = result.json['idToken'] as String;
  await _post(
    'https://identitytoolkit.googleapis.com/v1/accounts:update?key=$_apiKey',
    {'idToken': token, 'displayName': account.name},
  );
  return (uid: result.json['localId'] as String, token: token);
}

Future<void> _saveProfile(
  DemoAccount account,
  ({String uid, String token}) user,
) {
  return _commit(user.token, [
    _set('users/${user.uid}', {
      'displayName': account.name,
      'email': account.email,
      'role': account.role,
      if (account.businessName.isNotEmpty) 'businessName': account.businessName,
      'createdAt': _today.subtract(const Duration(days: 30)),
      'settings': {'notificationsEnabled': true},
    }, merge: true),
  ]);
}

Map<String, Object?> _set(
  String path,
  Map<String, Object?> data, {
  bool merge = false,
}) {
  return {
    'update': {
      'name': '$_root/$path',
      'fields': {
        for (final entry in data.entries) entry.key: _value(entry.value),
      },
    },
    if (merge) 'updateMask': {'fieldPaths': data.keys.toList()},
  };
}

Future<void> _commit(
  String token,
  List<Map<String, Object?>> writes, {
  bool quiet = false,
}) async {
  final result = await _post('$_documents:commit', {
    'writes': writes,
  }, token: token);
  if (result.status != 200 && !quiet) {
    throw StateError('Firestore refused the write: ${result.body}');
  }
}

Map<String, Object?> _value(Object? value) {
  if (value == null) return {'nullValue': null};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': '$value'};
  if (value is double) return {'doubleValue': value};
  if (value is String) return {'stringValue': value};
  if (value is DateTime) {
    return {'timestampValue': value.toUtc().toIso8601String()};
  }
  if (value is List) {
    return {
      'arrayValue': {'values': value.map(_value).toList()},
    };
  }
  if (value is Map) {
    return {
      'mapValue': {
        'fields': {
          for (final entry in value.entries)
            entry.key as String: _value(entry.value),
        },
      },
    };
  }
  throw ArgumentError('Unsupported value $value');
}

Future<({int status, String body, Map<String, dynamic> json})> _post(
  String url,
  Object body, {
  String? token,
}) async {
  final request = await _http.postUrl(Uri.parse(url));
  request.headers.contentType = ContentType.json;
  if (token != null) {
    request.headers.set('Authorization', 'Bearer $token');
  }
  request.write(jsonEncode(body));
  final response = await request.close();
  final text = await response.transform(utf8.decoder).join();
  Map<String, dynamic> json;
  try {
    json = jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    json = const {};
  }
  return (status: response.statusCode, body: text, json: json);
}
