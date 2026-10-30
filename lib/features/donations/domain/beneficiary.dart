import 'package:flutter/material.dart';

enum BeneficiaryType { restaurant, association }

/// A partner restaurant or a local charity that can collect donations.
///
/// There are no separate beneficiary accounts yet, so a fixed list of sample
/// partners is used to simulate requests (see the cahier des charges).
class Beneficiary {
  const Beneficiary({
    required this.id,
    required this.name,
    required this.type,
    required this.area,
  });

  final String id;
  final String name;
  final BeneficiaryType type;
  final String area;
}

const sampleBeneficiaries = <Beneficiary>[
  Beneficiary(
    id: 'ben-1',
    name: 'Restos du Cœur',
    type: BeneficiaryType.association,
    area: 'City centre',
  ),
  Beneficiary(
    id: 'ben-2',
    name: 'Croissant Rouge – local branch',
    type: BeneficiaryType.association,
    area: 'North district',
  ),
  Beneficiary(
    id: 'ben-3',
    name: 'Le Jardin Solidaire',
    type: BeneficiaryType.restaurant,
    area: 'Old town',
  ),
  Beneficiary(
    id: 'ben-4',
    name: 'Chez Amina – partner restaurant',
    type: BeneficiaryType.restaurant,
    area: 'South district',
  ),
];

String beneficiaryTypeLabel(BeneficiaryType type) {
  switch (type) {
    case BeneficiaryType.restaurant:
      return 'Partner restaurant';
    case BeneficiaryType.association:
      return 'Charity';
  }
}

IconData beneficiaryTypeIcon(BeneficiaryType type) {
  switch (type) {
    case BeneficiaryType.restaurant:
      return Icons.storefront_rounded;
    case BeneficiaryType.association:
      return Icons.volunteer_activism_rounded;
  }
}
