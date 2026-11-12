import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/domain/auth_validators.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../data/profile_photo.dart';
import '../data/user_profile_repository.dart';
import 'widgets/profile_avatar.dart';

/// Change the display name and the profile photo.
/// Pops with a message for the Profile screen to show.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.repository, this.photoPicker});

  /// Defaults to [UserProfileRepository.instance]; injectable for tests.
  final UserProfileRepository? repository;

  /// Defaults to [pickProfilePhoto]; injectable for tests.
  final ProfilePhotoPicker? photoPicker;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: _repository.profile?.displayName ?? '',
  );
  bool _saving = false;
  String? _error;

  UserProfileRepository get _repository =>
      widget.repository ?? UserProfileRepository.instance;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _changePhoto(ImageSource source) async {
    try {
      final picker = widget.photoPicker ?? pickProfilePhoto;
      final photo = await picker(source);
      if (photo != null) {
        _repository.updatePhoto(photo);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not use this photo. Try another one.');
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('photo-gallery-option'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _changePhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              key: const ValueKey('photo-camera-option'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _changePhoto(ImageSource.camera);
              },
            ),
            if (_repository.profile?.hasPhoto ?? false)
              ListTile(
                key: const ValueKey('photo-remove-option'),
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _repository.updatePhoto(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.updateDisplayName(_nameController.text);
      if (mounted) {
        Navigator.of(context).pop<String>('Profile updated');
      }
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = failure.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ScreenHeader(title: 'Edit profile'),
                const SizedBox(height: 24),
                Center(
                  child: ListenableBuilder(
                    listenable: _repository,
                    builder: (context, _) => GestureDetector(
                      key: const ValueKey('edit-profile-photo'),
                      onTap: _showPhotoOptions,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ProfileAvatar(profile: _repository.profile),
                          Positioned(
                            right: -6,
                            bottom: -6,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E7D32),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  key: const ValueKey('edit-profile-name-field'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  validator: validateDisplayName,
                  decoration: authInputDecoration(
                    label: 'Name',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  initialValue: _repository.profile?.email ?? '',
                  enabled: false,
                  decoration: authInputDecoration(
                    label: 'Email',
                    icon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 28),
                FormError(_error),
                PrimaryButton(
                  key: const ValueKey('edit-profile-save-button'),
                  label: 'Save',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
