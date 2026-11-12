import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/presentation/widgets/role_profile_tab.dart';

/// Start screen of restaurants and admins: one tab for their donation work
/// and a Profile tab. The first tab is a placeholder until the donation
/// workflow (restaurants request, admin decides) is built by the donations
/// owner.
class RoleShell extends StatefulWidget {
  const RoleShell({
    super.key,
    required this.tabLabel,
    required this.tabIcon,
    required this.title,
    required this.emptyMessage,
    this.profiles,
    this.auth,
  });

  final String tabLabel;
  final IconData tabIcon;
  final String title;
  final String emptyMessage;
  final UserProfileRepository? profiles;
  final AuthRepository? auth;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 22),
                  EmptyCard(icon: widget.tabIcon, message: widget.emptyMessage),
                ],
              ),
            ),
            RoleProfileTab(profiles: widget.profiles, auth: widget.auth),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: Icon(widget.tabIcon),
            label: widget.tabLabel,
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
