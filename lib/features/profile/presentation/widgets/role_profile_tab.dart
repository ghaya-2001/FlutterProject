import 'package:flutter/material.dart';

import '../../../../shared/widgets/screen_header.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/session_actions.dart';
import '../../data/user_profile_repository.dart';
import '../edit_profile_screen.dart';
import '../settings_screen.dart';
import 'profile_avatar.dart';

/// Profile tab of restaurants and admins: who they are, Edit profile,
/// Settings and logout.
class RoleProfileTab extends StatelessWidget {
  const RoleProfileTab({super.key, this.profiles, this.auth});

  final UserProfileRepository? profiles;
  final AuthRepository? auth;

  @override
  Widget build(BuildContext context) {
    final profiles = this.profiles ?? UserProfileRepository.instance;
    final auth = this.auth ?? AuthRepository.instance;
    return ListenableBuilder(
      listenable: profiles,
      builder: (context, _) {
        final profile = profiles.profile;
        final name = (profile?.businessName.isNotEmpty ?? false)
            ? profile!.businessName
            : profile?.displayName ?? '';
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'My profile',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              ProfileAvatar(profile: profile),
              const SizedBox(height: 16),
              Text(
                name,
                key: const ValueKey('role-profile-name'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1B1B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                profile?.email ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Chip(
                key: const ValueKey('role-profile-role'),
                label: Text(profiles.role.label),
                backgroundColor: const Color(0xFFE8F5E9),
                side: BorderSide.none,
              ),
              const SizedBox(height: 22),
              _RoleAction(
                key: const ValueKey('role-profile-edit'),
                icon: Icons.edit_outlined,
                title: 'Edit profile',
                onTap: () async {
                  final message = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (context) =>
                          EditProfileScreen(repository: profiles),
                    ),
                  );
                  if (message != null && context.mounted) {
                    showAppSnackBar(context, message);
                  }
                },
              ),
              const SizedBox(height: 12),
              _RoleAction(
                key: const ValueKey('role-profile-settings'),
                icon: Icons.settings_rounded,
                title: 'Settings',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          SettingsScreen(auth: auth, profiles: profiles),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _RoleAction(
                key: const ValueKey('role-profile-logout'),
                icon: Icons.logout_rounded,
                title: 'Logout',
                onTap: () => confirmAndSignOut(context, auth: auth),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoleAction extends StatelessWidget {
  const _RoleAction({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2E7D32)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
