import 'package:flutter/material.dart';

import '../../auth/data/auth_repository.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/presentation/widgets/role_profile_tab.dart';

/// One bottom-bar tab of [RoleShell].
class RoleTab {
  const RoleTab({required this.label, required this.icon, required this.child});

  final String label;
  final IconData icon;
  final Widget child;
}

/// Start screen of restaurants and admins: their own tabs (donations, stock,
/// history...) followed by a Profile tab.
class RoleShell extends StatefulWidget {
  const RoleShell({super.key, required this.tabs, this.profiles, this.auth});

  final List<RoleTab> tabs;
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
            for (final tab in widget.tabs) tab.child,
            RoleProfileTab(profiles: widget.profiles, auth: widget.auth),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          for (final tab in widget.tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
