import 'package:flutter/material.dart';

import '../../auth/data/auth_repository.dart';
import '../../donations/data/donation_repository.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/presentation/fridge_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/user_role.dart';
import 'admin_requests_tab.dart';
import 'request_history_tab.dart';
import 'restaurant_donations_tab.dart';
import 'role_shell.dart';

/// Start screen after sign-in: each role gets its own app.
///
/// - user: the full app.
/// - restaurant: Donations (request), Stock (its own fridge), History (its
///   requests) and Profile.
/// - admin: Requests (accept or refuse), History (answered requests) and
///   Profile.
class RoleHome extends StatelessWidget {
  const RoleHome({
    super.key,
    this.profiles,
    this.auth,
    this.donations,
    this.fridge,
  });

  /// Defaults to [DonationRepository.instance]; injectable for tests.
  final DonationRepository? donations;

  /// Stock of restaurants; defaults to [FridgeRepository.instance].
  final FridgeRepository? fridge;

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
              tabs: [
                RoleTab(
                  label: 'Donations',
                  icon: Icons.volunteer_activism_outlined,
                  child: RestaurantDonationsTab(
                    title: 'Available donations',
                    emptyMessage: 'Donations offered by users will appear here, so you can request them.',
                    donations: donations,
                    profiles: profiles,
                  ),
                ),
                RoleTab(
                  label: 'Stock',
                  icon: Icons.kitchen_outlined,
                  child: FridgeScreen(
                    repository: fridge,
                    embedded: true,
                    canDonate: false,
                  ),
                ),
                RoleTab(
                  label: 'History',
                  icon: Icons.history_rounded,
                  child: RequestHistoryTab(
                    title: 'My requests',
                    emptyMessage: 'The donations you request will be listed here with their answer.',
                    forRestaurant: true,
                    donations: donations,
                    profiles: profiles,
                  ),
                ),
              ],
            );
          case UserRole.admin:
            return RoleShell(
              key: const ValueKey('admin-shell'),
              profiles: profiles,
              auth: auth,
              tabs: [
                RoleTab(
                  label: 'Requests',
                  icon: Icons.fact_check_outlined,
                  child: AdminRequestsTab(
                    title: 'Pending requests',
                    emptyMessage: 'Donation requests from restaurants will appear here for you to accept or refuse.',
                    donations: donations,
                  ),
                ),
                RoleTab(
                  label: 'History',
                  icon: Icons.history_rounded,
                  child: RequestHistoryTab(
                    title: 'Answered requests',
                    emptyMessage:
                        'Requests you accept or refuse will be listed here.',
                    forRestaurant: false,
                    donations: donations,
                    profiles: profiles,
                  ),
                ),
              ],
            );
        }
      },
    );
  }
}
