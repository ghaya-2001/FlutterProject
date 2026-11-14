import 'package:flutter/material.dart';

import '../../auth/data/auth_repository.dart';
import '../../home/presentation/home_screen.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/user_role.dart';
import '../../donations/data/donation_repository.dart';
import 'admin_requests_tab.dart';
import 'restaurant_donations_tab.dart';
import 'role_shell.dart';

/// Start screen after sign-in: each role gets its own app.
class RoleHome extends StatelessWidget {
  const RoleHome({super.key, this.profiles, this.auth, this.donations});

  /// Defaults to [DonationRepository.instance]; injectable for tests.
  final DonationRepository? donations;

  /// Defaults to [UserProfileRepository.instance]; injectable for tests.
  final UserProfileRepository? profiles;

  /// Defaults to [AuthRepository.instance]; injectable for tests.
  final AuthRepository? auth;

  @override
  Widget build(BuildContext context) {
    final profiles = this.profiles ?? UserProfileRepository.instance;
    return ListenableBuilder(
      listenable: profiles,
      builder: (context, _) {
        switch (profiles.role) {
          case UserRole.user:
            return const FoodSaverHomePage();
          case UserRole.restaurant:
            return RoleShell(
              key: const ValueKey('restaurant-shell'),
              profiles: profiles,
              auth: auth,
              tabLabel: 'Donations',
              tabIcon: Icons.volunteer_activism_outlined,
              title: 'Available donations',
              emptyMessage: 'Donations offered by users will appear here, so you can request them.',
              tab: RestaurantDonationsTab(
                title: 'Available donations',
                emptyMessage: 'Donations offered by users will appear here, so you can request them.',
                donations: donations,
                profiles: profiles,
              ),
            );
          case UserRole.admin:
            return RoleShell(
              key: const ValueKey('admin-shell'),
              profiles: profiles,
              auth: auth,
              tabLabel: 'Requests',
              tabIcon: Icons.fact_check_outlined,
              title: 'Pending requests',
              emptyMessage: 'Donation requests from restaurants will appear here for you to accept or refuse.',
              tab: AdminRequestsTab(
                title: 'Pending requests',
                emptyMessage: 'Donation requests from restaurants will appear here for you to accept or refuse.',
                donations: donations,
              ),
            );
        }
      },
    );
  }
}
