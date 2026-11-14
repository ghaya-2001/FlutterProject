// ignore_for_file: prefer_initializing_formals (private field, named parameter)
import 'package:flutter/material.dart';

import '../../expiry/domain/expiry_alerts.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/domain/food_category.dart';
import '../../fridge/domain/food_item.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../../notifications/data/notification_repository.dart';
import '../domain/beneficiary.dart';
import '../domain/donation.dart';
import '../../../core/firebase/firebase_setup.dart';
import '../../../core/session/current_user.dart';
import 'donation_firestore.dart';

/// In-memory store for the donations module.
///
/// Donations are created from fridge foods: the donated quantity is removed
/// from the fridge, and given back if the donation is cancelled.
class DonationRepository extends ChangeNotifier {
  DonationRepository({
    FridgeRepository? fridge,
    this.notifications,
    this.remote,
    String? userId,
    bool seed = true,
    bool autoConnect = true,
  }) : fridge = fridge ?? FridgeRepository.instance,
       _userId = userId,
       _seedDemo = seed {
    if (remote != null) {
      if (autoConnect) {
        _loadRemote();
      }
    } else if (seed) {
      _seed();
    }
  }

  static final DonationRepository instance = DonationRepository(
    notifications: NotificationRepository.instance,
    remote: FirebaseSetup.isReady ? DonationFirestore() : null,
    autoConnect: false,
  );

  final bool _seedDemo;

  final FridgeRepository fridge;

  /// Firestore storage; null in tests or when Firebase is not configured.
  final DonationFirestore? remote;

  final String? _userId;

  /// The donor using the app: the signed-in user, unless a fixed id was
  /// given (tests).
  String get userId => _userId ?? CurrentUser.uid;

  /// Receives an event when a beneficiary asks for a donation.
  final NotificationRepository? notifications;
  final List<Donation> _donations = [];
  int _idCounter = 0;

  DateTime get now => fridge.now;

  /// True when [donation] was published by the current user.
  bool isMine(Donation donation) => donation.donorId == userId;

  /// The current user's donations, newest first.
  List<Donation> get donations => _sorted(_donations.where(isMine));

  /// Donations that are not collected yet (available or reserved).
  List<Donation> get activeDonations => donations
      .where((donation) => donation.status != DonationStatus.collected)
      .toList();

  /// Donations beneficiaries can still ask for, from every user.
  List<Donation> get availableDonations => _sorted(_donations)
      .where(
        (donation) =>
            donation.status == DonationStatus.available &&
            !_isPast(donation.expiryDate),
      )
      .toList();

  /// Donations from every user with a request waiting for the admin's answer,
  /// oldest request first.
  List<Donation> get donationsAwaitingAnswer {
    final result = _donations
        .where(
          (donation) =>
              donation.status == DonationStatus.available &&
              donation.pendingRequests.isNotEmpty,
        )
        .toList();
    DateTime oldest(Donation d) => d.pendingRequests
        .map((request) => request.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    result.sort((a, b) => oldest(a).compareTo(oldest(b)));
    return result;
  }

  /// Every request on every donation, newest request first. With
  /// [beneficiaryId] only the requests sent by that account (a restaurant's
  /// own history); [includePending] false keeps the answered ones (the
  /// admin's history).
  List<RequestRecord> requestRecords({
    String? beneficiaryId,
    bool includePending = true,
  }) {
    final result = <RequestRecord>[
      for (final donation in _donations)
        for (final request in donation.requests)
          if ((beneficiaryId == null ||
                  request.beneficiary.id == beneficiaryId) &&
              (includePending || request.status != RequestStatus.pending))
            RequestRecord(donation: donation, request: request),
    ];
    result.sort((a, b) => b.request.createdAt.compareTo(a.request.createdAt));
    return result;
  }

  int get collectedCount => donations
      .where((donation) => donation.status == DonationStatus.collected)
      .length;

  int get pendingRequestCount => donations.fold(
    0,
    (total, donation) => total + donation.pendingRequests.length,
  );

  Donation? donationById(String id) {
    for (final donation in _donations) {
      if (donation.id == id) {
        return donation;
      }
    }
    return null;
  }

  /// Fridge foods that can still be donated (not expired), soonest first.
  List<FoodItem> get donatableFoods {
    final result = fridge.items.where((item) => !item.isExpired(now)).toList();
    result.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return result;
  }

  /// Foods worth donating now: they expire within [expiringSoonDays].
  List<FoodItem> get suggestedFoods => expiringSoon(fridge.items, now);

  // ---------------------------------------------------------------------------
  // Donor actions
  // ---------------------------------------------------------------------------

  /// Offers [quantity] of the fridge food [foodId].
  ///
  /// [expiryDate] is the consume-by date shown to beneficiaries. It cannot be
  /// later than the fridge expiry date, which stays the reference.
  Donation createDonation({
    required String foodId,
    required double quantity,
    required DateTime expiryDate,
    String description = '',
  }) {
    final food = fridge.itemById(foodId);
    if (food == null) {
      throw ArgumentError('Food $foodId not found');
    }
    if (food.isExpired(now)) {
      throw ArgumentError('Expired food cannot be donated');
    }
    if (quantity <= 0 || quantity > food.quantity) {
      throw ArgumentError(
        'Quantity must be between 0 and ${formatQuantity(food.quantity)}',
      );
    }
    final date = DateUtils.dateOnly(expiryDate);
    if (date.isAfter(DateUtils.dateOnly(food.expiryDate))) {
      throw ArgumentError('Date cannot be after the fridge expiry date');
    }
    if (_isPast(date)) {
      throw ArgumentError('Date cannot be in the past');
    }

    final donation = Donation(
      id: _newId(),
      donorId: userId,
      foodId: food.id,
      foodName: food.name,
      category: food.category,
      quantity: quantity,
      unit: food.unit,
      expiryDate: date,
      createdAt: now,
      description: description.trim(),
    );
    // The donated part leaves the fridge stock (not counted as eaten).
    fridge.consume(food.id, quantity, record: false);
    _donations.add(donation);
    notifyListeners();
    _sync(() => remote!.save(donation));
    return donation;
  }

  /// Withdraws an available donation and gives the quantity back to the
  /// fridge.
  void cancelDonation(String donationId) {
    final donation = _require(donationId);
    if (donation.status != DonationStatus.available) {
      throw StateError('Only available donations can be cancelled');
    }
    final food = fridge.itemById(donation.foodId);
    if (food != null) {
      final total = ((food.quantity + donation.quantity) * 1000).round() / 1000;
      fridge.updateFood(food.copyWith(quantity: total));
    } else {
      // The rest of the food was eaten meanwhile: put the donation back.
      fridge.addFood(
        name: donation.foodName,
        category:
            fridge.categoryNamed(donation.category.name) ?? otherFoodCategory,
        quantity: donation.quantity,
        unit: donation.unit,
        expiryDate: donation.expiryDate,
      );
    }
    _donations.removeWhere((d) => d.id == donationId);
    notifyListeners();
    _sync(() => remote!.delete(donationId));
  }

  /// Accepts one request: the donation becomes reserved for that
  /// beneficiary and the other pending requests are refused.
  void acceptRequest(String donationId, String requestId) {
    final donation = _require(donationId);
    if (donation.status != DonationStatus.available) {
      throw StateError('This donation is already ${donation.status.name}');
    }
    _requireRequest(donation, requestId);
    final requests = donation.requests.map((request) {
      if (request.id == requestId) {
        return request.copyWith(status: RequestStatus.accepted);
      }
      if (request.status == RequestStatus.pending) {
        return request.copyWith(status: RequestStatus.refused);
      }
      return request;
    }).toList();
    _replace(
      donation.copyWith(status: DonationStatus.reserved, requests: requests),
    );
  }

  /// Refuses one request. The donation stays available.
  void refuseRequest(String donationId, String requestId) {
    final donation = _require(donationId);
    final request = _requireRequest(donation, requestId);
    if (request.status != RequestStatus.pending) {
      throw StateError('This request was already answered');
    }
    final requests = donation.requests
        .map(
          (r) =>
              r.id == requestId ? r.copyWith(status: RequestStatus.refused) : r,
        )
        .toList();
    _replace(donation.copyWith(requests: requests));
  }

  /// The beneficiary picked the food up.
  void markCollected(String donationId) {
    final donation = _require(donationId);
    if (donation.status != DonationStatus.reserved) {
      throw StateError('Only reserved donations can be collected');
    }
    _replace(
      donation.copyWith(status: DonationStatus.collected, collectedAt: now),
    );
  }

  // ---------------------------------------------------------------------------
  // Beneficiary actions (simulated: there are no beneficiary accounts yet)
  // ---------------------------------------------------------------------------

  DonationRequest requestDonation(
    String donationId,
    Beneficiary beneficiary, {
    String message = '',
  }) {
    final donation = _require(donationId);
    if (donation.status != DonationStatus.available) {
      throw StateError('This donation is no longer available');
    }
    if (hasPendingRequestFrom(donation, beneficiary)) {
      throw StateError('${beneficiary.name} already asked for this donation');
    }
    final request = DonationRequest(
      id: _newId(),
      beneficiary: beneficiary,
      createdAt: now,
      message: message.trim(),
    );
    _replace(donation.copyWith(requests: [...donation.requests, request]));
    notifications?.addDonationEvent(
      title: 'New request for ${donation.foodName}',
      body: '${beneficiary.name} would like to collect your donation.',
      donationId: donation.id,
    );
    return request;
  }

  bool hasPendingRequestFrom(Donation donation, Beneficiary beneficiary) =>
      donation.pendingRequests.any(
        (request) => request.beneficiary.id == beneficiary.id,
      );

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<Donation> _sorted(Iterable<Donation> donations) {
    final result = [...donations];
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  bool _isPast(DateTime date) =>
      DateUtils.dateOnly(date).isBefore(DateUtils.dateOnly(now));

  Donation _require(String donationId) {
    final donation = donationById(donationId);
    if (donation == null) {
      throw ArgumentError('Donation $donationId not found');
    }
    return donation;
  }

  DonationRequest _requireRequest(Donation donation, String requestId) {
    for (final request in donation.requests) {
      if (request.id == requestId) {
        return request;
      }
    }
    throw ArgumentError('Request $requestId not found');
  }

  void _replace(Donation updated) {
    final index = _donations.indexWhere((d) => d.id == updated.id);
    _donations[index] = updated;
    notifyListeners();
    _sync(() => remote!.save(updated));
  }

  /// Loads the donations (after [clear]).
  void connect() {
    if (remote != null) {
      _loadRemote();
    } else if (_seedDemo) {
      _seed();
      notifyListeners();
    }
  }

  /// Forgets every donation held in memory.
  void clear() {
    _donations.clear();
    notifyListeners();
  }

  /// Loads the donations again, so donations published or answered by other
  /// accounts since sign-in show up (restaurants only see them this way).
  Future<void> refresh() async {
    if (remote != null) {
      await _loadRemote(replace: true);
    }
  }

  Future<void> _loadRemote({bool replace = false}) async {
    try {
      final maps = await remote!.loadAll();
      final loaded = [
        for (final map in maps)
          donationFromMap(
            map,
            (name) => fridge.categoryNamed(name) ?? otherFoodCategory,
          ),
      ];
      if (replace) {
        _donations
          ..clear()
          ..addAll(loaded);
      } else {
        for (final donation in loaded) {
          if (donationById(donation.id) == null) {
            _donations.add(donation);
          }
        }
      }
      notifyListeners();
    } catch (error) {
      debugPrint('Could not load donations: $error');
    }
  }

  /// Runs a Firestore write without blocking the screen.
  void _sync(Future<void> Function() write) {
    if (remote == null) {
      return;
    }
    write().catchError(
      (Object error) => debugPrint('Could not save donation: $error'),
    );
  }

  String _newId() =>
      'don-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  void _seed() {
    final today = DateUtils.dateOnly(now);
    FoodCategory category(String name) =>
        fridge.categoryNamed(name) ?? otherFoodCategory;

    _donations.addAll([
      Donation(
        id: _newId(),
        donorId: userId,
        foodId: 'seed-bread',
        foodName: 'Bread',
        category: category('Bakery'),
        quantity: 2,
        unit: 'pcs',
        expiryDate: today.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 4)),
        description: 'Two fresh loaves, bought too many.',
        status: DonationStatus.collected,
        collectedAt: now.subtract(const Duration(days: 3)),
        requests: [
          DonationRequest(
            id: _newId(),
            beneficiary: sampleBeneficiaries[0],
            createdAt: now.subtract(const Duration(days: 4)),
            status: RequestStatus.accepted,
          ),
        ],
      ),
      Donation(
        id: _newId(),
        donorId: userId,
        foodId: 'seed-rice',
        foodName: 'Rice',
        category: category('Pantry'),
        quantity: 1,
        unit: 'kg',
        expiryDate: today.add(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(hours: 5)),
        description: 'Unopened pack.',
        requests: [
          DonationRequest(
            id: _newId(),
            beneficiary: sampleBeneficiaries[2],
            createdAt: now.subtract(const Duration(hours: 2)),
            message: 'We can pick it up this evening.',
          ),
        ],
      ),
    ]);
  }
}
