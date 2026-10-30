import 'package:flutter/material.dart';

import '../../fridge/domain/food_category.dart';
import 'beneficiary.dart';

enum DonationStatus { available, reserved, collected }

enum RequestStatus { pending, accepted, refused }

/// A request sent by a beneficiary to collect a donation.
class DonationRequest {
  const DonationRequest({
    required this.id,
    required this.beneficiary,
    required this.createdAt,
    this.message = '',
    this.status = RequestStatus.pending,
  });

  final String id;
  final Beneficiary beneficiary;
  final DateTime createdAt;
  final String message;
  final RequestStatus status;

  DonationRequest copyWith({RequestStatus? status}) {
    return DonationRequest(
      id: id,
      beneficiary: beneficiary,
      createdAt: createdAt,
      message: message,
      status: status ?? this.status,
    );
  }
}

/// A food offered for donation.
///
/// The name, category and unit are copied from the fridge when the donation
/// is created: the donated quantity leaves the fridge, so the donation must
/// keep its own description even if the food is later removed from it.
class Donation {
  const Donation({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
    required this.createdAt,
    this.donorId = '',
    this.description = '',
    this.status = DonationStatus.available,
    this.requests = const [],
    this.collectedAt,
  });

  final String id;

  /// User who offers the food (see `currentUserId`).
  final String donorId;

  /// Id of the fridge food this donation comes from.
  final String foodId;
  final String foodName;
  final FoodCategory category;
  final double quantity;
  final String unit;

  /// Consume-by date. Never later than the fridge expiry date of the food.
  final DateTime expiryDate;
  final DateTime createdAt;
  final String description;
  final DonationStatus status;
  final List<DonationRequest> requests;
  final DateTime? collectedAt;

  List<DonationRequest> get pendingRequests => requests
      .where((request) => request.status == RequestStatus.pending)
      .toList();

  /// The beneficiary whose request was accepted, if any.
  DonationRequest? get acceptedRequest {
    for (final request in requests) {
      if (request.status == RequestStatus.accepted) {
        return request;
      }
    }
    return null;
  }

  Donation copyWith({
    DonationStatus? status,
    List<DonationRequest>? requests,
    DateTime? collectedAt,
  }) {
    return Donation(
      id: id,
      donorId: donorId,
      foodId: foodId,
      foodName: foodName,
      category: category,
      quantity: quantity,
      unit: unit,
      expiryDate: expiryDate,
      createdAt: createdAt,
      description: description,
      status: status ?? this.status,
      requests: requests ?? this.requests,
      collectedAt: collectedAt ?? this.collectedAt,
    );
  }
}

String donationStatusLabel(DonationStatus status) {
  switch (status) {
    case DonationStatus.available:
      return 'Available';
    case DonationStatus.reserved:
      return 'Reserved';
    case DonationStatus.collected:
      return 'Collected';
  }
}

Color donationStatusColor(DonationStatus status) {
  switch (status) {
    case DonationStatus.available:
      return const Color(0xFF2E7D32);
    case DonationStatus.reserved:
      return const Color(0xFFE65100);
    case DonationStatus.collected:
      return const Color(0xFF1565C0);
  }
}

Color donationStatusBackground(DonationStatus status) {
  switch (status) {
    case DonationStatus.available:
      return const Color(0xFFE8F5E9);
    case DonationStatus.reserved:
      return const Color(0xFFFFF3E0);
    case DonationStatus.collected:
      return const Color(0xFFE3F2FD);
  }
}

String requestStatusLabel(RequestStatus status) {
  switch (status) {
    case RequestStatus.pending:
      return 'Waiting for your answer';
    case RequestStatus.accepted:
      return 'Accepted';
    case RequestStatus.refused:
      return 'Refused';
  }
}
