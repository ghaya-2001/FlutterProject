import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/session_actions.dart';
import '../../donations/data/donation_repository.dart';
import '../../donations/presentation/donation_history_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../list/data/shopping_list_repository.dart';
import '../../fridge/presentation/fridge_screen.dart';
import '../../list/presentation/list_screen.dart';
import '../data/user_profile_repository.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'widgets/profile_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.auth, this.profiles});

  /// Default to the app-wide instances; injectable for tests.
  final AuthRepository? auth;
  final UserProfileRepository? profiles;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 3;
  bool _verifyBannerDismissed = false;

  AuthRepository get _auth => widget.auth ?? AuthRepository.instance;
  UserProfileRepository get _profiles =>
      widget.profiles ?? UserProfileRepository.instance;

  Future<void> _edit() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(repository: _profiles),
      ),
    );
    if (message != null && mounted) {
      showAppSnackBar(context, message);
    }
  }

  Future<void> _resendVerification() async {
    try {
      await _auth.sendEmailVerification();
      if (mounted) {
        showAppSnackBar(context, 'Verification email sent');
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not send the email. Try again later.');
      }
    }
  }

  Future<void> _refreshVerification() async {
    try {
      await _auth.reloadUser();
    } catch (_) {}
    if (mounted && !(_auth.currentUser?.emailVerified ?? true)) {
      showAppSnackBar(context, 'Your email is not verified yet');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_auth, _profiles]),
          builder: (context, _) => _buildBody(context),
        ),
      ),
      bottomNavigationBar: _buildNavigationBar(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final profile = _profiles.profile;
    final user = _auth.currentUser;
    final name = (profile?.displayName.isNotEmpty ?? false)
        ? profile!.displayName
        : (user?.displayName.isNotEmpty ?? false)
        ? user!.displayName
        : 'Food saver';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeader(title: 'My profile'),
          const SizedBox(height: 18),
          if (user != null && !user.emailVerified && !_verifyBannerDismissed)
            _VerifyEmailBanner(
              email: user.email,
              onResend: _resendVerification,
              onRefresh: _refreshVerification,
              onDismiss: () => setState(() => _verifyBannerDismissed = true),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB7E4C7), Color(0xFFE9F7EC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                ProfileAvatar(
                  key: const ValueKey('profile-avatar'),
                  profile: profile,
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  key: const ValueKey('profile-name'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  profile?.email ?? user?.email ?? '',
                  key: const ValueKey('profile-email'),
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const ValueKey('profile-edit-button'),
                  onPressed: profile == null ? null : _edit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: const [
              Expanded(
                child: _ProfileStatCard(
                  value: '128',
                  label: 'Meals saved',
                  color: Color(0xFFB2DFDB),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: _ProfileStatCard(
                  value: '92%',
                  label: 'Impact',
                  color: Color(0xFFFFE082),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ProfileOptionRow(
            icon: Icons.favorite_rounded,
            title: 'Saved recipes',
            subtitle: '18 favorites',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _ProfileOptionRow(
            icon: Icons.shopping_basket_rounded,
            title: 'My shopping list',
            subtitle:
                '${ShoppingListRepository.instance.totalRemainingCount} items to buy',
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ListScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _ProfileOptionRow(
            icon: Icons.volunteer_activism_rounded,
            title: 'My donations',
            subtitle:
                '${DonationRepository.instance.collectedCount} collected · history',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DonationHistoryScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ProfileOptionRow(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'Preferences & alerts',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsScreen(auth: _auth, profiles: _profiles),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    title: const Text('Log out?'),
                    content: const Text(
                      'Are you sure you want to leave your food-saving journey?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('logout-confirm-button'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          signOutAndShowWelcome(context, auth: _auth);
                        },
                        child: const Text(
                          'Yes, log out',
                          style: TextStyle(color: Color(0xFF2E7D32)),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });

        if (index == 0) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const FoodSaverHomePage()),
          );
        }

        if (index == 1) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const FridgeScreen()),
          );
        }

        if (index == 2) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ListScreen()),
          );
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(
          icon: Icon(Icons.kitchen_outlined),
          label: 'Fridge',
        ),
        NavigationDestination(
          icon: Icon(Icons.list_alt_outlined),
          label: 'List',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }
}

class _VerifyEmailBanner extends StatelessWidget {
  const _VerifyEmailBanner({
    required this.email,
    required this.onResend,
    required this.onRefresh,
    required this.onDismiss,
  });

  final String email;
  final VoidCallback onResend;
  final VoidCallback onRefresh;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('verify-email-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Verify your email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('verify-email-dismiss'),
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          Text(
            'We sent a link to $email.',
            style: const TextStyle(color: Colors.black54),
          ),
          Row(
            children: [
              TextButton(
                key: const ValueKey('verify-email-resend'),
                onPressed: onResend,
                child: const Text('Resend'),
              ),
              TextButton(
                key: const ValueKey('verify-email-refresh'),
                onPressed: onRefresh,
                child: const Text("I've verified"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.eco_rounded, color: Color(0xFF1B1B1B)),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B1B1B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ProfileOptionRow extends StatelessWidget {
  const _ProfileOptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF2E7D32)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF2E7D32)),
          ],
        ),
      ),
    );
  }
}
