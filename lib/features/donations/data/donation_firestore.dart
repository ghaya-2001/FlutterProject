import 'package:cloud_firestore/cloud_firestore.dart';

import '../../fridge/domain/food_category.dart';
import '../domain/beneficiary.dart';
import '../domain/donation.dart';

/// Reads and writes donations in Firestore.
///
/// Structure:
/// ```
/// donations/{donationId}   donorId, foodName, category, quantity, unit,
///                          expiryDate, status, requests: [...], ...
/// ```
/// Donations are in a top-level collection (not under a user) because
/// restaurants and charities must be able to see every available donation.
/// Requests are stored inside their donation: there are only a few per
/// donation and they are always shown together.
class DonationFirestore {
  DonationFirestore({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _donations =>
      _db.collection('donations');

  Future<List<Map<String, dynamic>>> loadAll() async {
    final snapshot = await _donations.get();
    return [
      for (final doc in snapshot.docs) {...doc.data(), 'id': doc.id},
    ];
  }

  Future<void> save(Donation donation) =>
      _donations.doc(donation.id).set(donationToMap(donation));

  Future<void> delete(String donationId) => _donations.doc(donationId).delete();
}

// -----------------------------------------------------------------------------
// Conversion between the models and Firestore maps
// -----------------------------------------------------------------------------

Map<String, dynamic> donationToMap(Donation donation) {
  return {
    'donorId': donation.donorId,
    'foodId': donation.foodId,
    'foodName': donation.foodName,
    // Only the name is stored: icon and color come from the app.
    'category': donation.category.name,
    'quantity': donation.quantity,
    'unit': donation.unit,
    'expiryDate': Timestamp.fromDate(donation.expiryDate),
    'createdAt': Timestamp.fromDate(donation.createdAt),
    'description': donation.description,
    'status': donation.status.name,
    'collectedAt': donation.collectedAt == null
        ? null
        : Timestamp.fromDate(donation.collectedAt!),
    'requests': [
      for (final request in donation.requests) donationRequestToMap(request),
    ],
  };
}

Map<String, dynamic> donationRequestToMap(DonationRequest request) {
  final beneficiary = request.beneficiary;
  return {
    'id': request.id,
    // The beneficiary is copied so the request stays readable on its own.
    'beneficiaryId': beneficiary.id,
    'beneficiaryName': beneficiary.name,
    'beneficiaryType': beneficiary.type.name,
    'beneficiaryArea': beneficiary.area,
    'message': request.message,
    'status': request.status.name,
    'createdAt': Timestamp.fromDate(request.createdAt),
  };
}

/// [categoryFor] turns a stored category name back into a fridge category.
Donation donationFromMap(
  Map<String, dynamic> map,
  FoodCategory Function(String name) categoryFor,
) {
  return Donation(
    id: map['id'] as String,
    donorId: map['donorId'] as String? ?? '',
    foodId: map['foodId'] as String? ?? '',
    foodName: map['foodName'] as String? ?? '',
    category: categoryFor(map['category'] as String? ?? 'Other'),
    quantity: (map['quantity'] as num? ?? 0).toDouble(),
    unit: map['unit'] as String? ?? 'pcs',
    expiryDate: _date(map['expiryDate']) ?? DateTime.now(),
    createdAt: _date(map['createdAt']) ?? DateTime.now(),
    description: map['description'] as String? ?? '',
    status: _enumByName(
      DonationStatus.values,
      map['status'],
      DonationStatus.available,
    ),
    collectedAt: _date(map['collectedAt']),
    requests: [
      for (final request in map['requests'] as List? ?? const [])
        donationRequestFromMap(Map<String, dynamic>.from(request as Map)),
    ],
  );
}

DonationRequest donationRequestFromMap(Map<String, dynamic> map) {
  return DonationRequest(
    id: map['id'] as String,
    beneficiary: Beneficiary(
      id: map['beneficiaryId'] as String? ?? '',
      name: map['beneficiaryName'] as String? ?? '',
      type: _enumByName(
        BeneficiaryType.values,
        map['beneficiaryType'],
        BeneficiaryType.association,
      ),
      area: map['beneficiaryArea'] as String? ?? '',
    ),
    message: map['message'] as String? ?? '',
    status: _enumByName(
      RequestStatus.values,
      map['status'],
      RequestStatus.pending,
    ),
    createdAt: _date(map['createdAt']) ?? DateTime.now(),
  );
}

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}
