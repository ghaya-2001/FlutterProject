import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/user_profile.dart';

/// Round-cornered profile picture: the saved photo, or the user's initials.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.size = 110});

  final UserProfile? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    final radius = BorderRadius.circular(size * 0.33);
    Widget child;
    if (profile != null && profile.hasPhoto) {
      child = Image.memory(
        base64Decode(profile.photoBase64!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _initials(profile),
      );
    } else {
      child = _initials(profile);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A2E7D32),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }

  Widget _initials(UserProfile? profile) {
    return Center(
      child: Text(
        profile?.initials ?? '?',
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2E7D32),
        ),
      ),
    );
  }
}
