import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_colors.dart';
import '../services/api_client.dart';
import '../user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.apiClient,
    this.demoMode = false,
  });

  final ApiClient apiClient;
  final bool demoMode;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _imagePicker = ImagePicker();

  UserProfile? _profile;
  Uint8List? _pickedAvatarBytes;
  String? _pickedAvatarFilename;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppColors.heading,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_error != null) ...[
                          _ProfileMessage(message: _error!, isError: true),
                          const SizedBox(height: 16),
                        ],
                        _buildAvatar(),
                        const SizedBox(height: 12),
                        Text(
                          '@${_profile?.username ?? ''}',
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.star_rounded, size: 18),
                              label: Text('Rating ${_profile?.rating ?? 0}'),
                            ),
                            Chip(
                              avatar: const Icon(
                                Icons.military_tech_rounded,
                                size: 18,
                              ),
                              label: Text('Level ${_profile?.level ?? 0}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: const Color(0xFFDDE9FF)),
                          ),
                          child: Column(
                            children: [
                              _ProfileField(
                                controller: _name,
                                label: 'Full name',
                                icon: Icons.person_outline_rounded,
                                textInputAction: TextInputAction.next,
                                validator: _requiredValidator('Name'),
                              ),
                              const SizedBox(height: 14),
                              _ProfileField(
                                controller: _email,
                                label: 'Email address',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: _emailValidator,
                              ),
                              const SizedBox(height: 14),
                              _ProfileField(
                                controller: _phone,
                                label: 'Contact number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 14),
                              _ProfileField(
                                controller: _address,
                                label: 'Address',
                                icon: Icons.location_on_outlined,
                                keyboardType: TextInputType.streetAddress,
                                minLines: 3,
                                maxLines: 5,
                                textInputAction: TextInputAction.newline,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _saveProfile,
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    _saving ? 'Saving...' : 'Save changes',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.deepPurple,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    final profile = _profile;
    ImageProvider<Object>? image;
    if (_pickedAvatarBytes != null) {
      image = MemoryImage(_pickedAvatarBytes!);
    } else if (profile?.avatarUrl != null) {
      image = NetworkImage(profile!.avatarUrl!);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 116,
          height: 116,
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.blue, AppColors.lavender],
            ),
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            key: const Key('profile-avatar'),
            backgroundColor: const Color(0xFFEFF6FF),
            backgroundImage: image,
            child: image == null
                ? Text(
                    _initials(profile?.name ?? ''),
                    style: const TextStyle(
                      color: AppColors.deepPurple,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
        ),
        Positioned(
          right: -4,
          bottom: 2,
          child: Material(
            color: AppColors.deepPurple,
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(
              key: const Key('pick-profile-avatar'),
              tooltip: 'Choose profile photo',
              color: Colors.white,
              onPressed: _pickAvatar,
              icon: const Icon(Icons.add_a_photo_outlined, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadProfile() async {
    try {
      final profile = widget.demoMode
          ? const UserProfile(
              id: 0,
              name: 'Demo Player',
              username: 'demo_player',
              email: 'demo@example.com',
              phoneNumber: '+977 9800000000',
              address: 'Kathmandu, Nepal',
              avatarUrl: null,
            )
          : await widget.apiClient.getProfile();
      if (!mounted) return;
      _applyProfile(profile);
      setState(() {
        _profile = profile;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyAppErrorMessage(error);
      });
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Profile photo must be 5 MB or smaller.');
      }
      if (!mounted) return;
      setState(() {
        _pickedAvatarBytes = bytes;
        _pickedAvatarFilename = image.name;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyAppErrorMessage(error));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = widget.demoMode
          ? UserProfile(
              id: _profile!.id,
              name: _name.text.trim(),
              username: _profile!.username,
              email: _email.text.trim(),
              phoneNumber: _phone.text.trim(),
              address: _address.text.trim(),
              avatarUrl: _profile!.avatarUrl,
              rating: _profile!.rating,
              level: _profile!.level,
            )
          : await widget.apiClient.updateProfile(
              name: _name.text.trim(),
              email: _email.text.trim(),
              phoneNumber: _phone.text.trim(),
              address: _address.text.trim(),
              avatarBytes: _pickedAvatarBytes,
              avatarFilename: _pickedAvatarFilename,
            );

      if (!mounted) return;
      _applyProfile(updated);
      setState(() {
        _profile = updated;
        if (!widget.demoMode) {
          _pickedAvatarBytes = null;
          _pickedAvatarFilename = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.demoMode
                ? 'Demo profile updated on this screen'
                : 'Profile updated successfully',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyAppErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _applyProfile(UserProfile profile) {
    _name.text = profile.name;
    _email.text = profile.email;
    _phone.text = profile.phoneNumber;
    _address.text = profile.address;
  }

  FormFieldValidator<String> _requiredValidator(String label) {
    return (value) =>
        value == null || value.trim().isEmpty ? '$label is required' : null;
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.textInputAction,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF7FAFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE9FF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE9FF)),
        ),
      ),
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFEEF0) : const Color(0xFFE8FFF2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? const Color(0xFFB42318) : const Color(0xFF16794C),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final populated = parts.where((part) => part.isNotEmpty).toList();
  if (populated.isEmpty) return '?';
  if (populated.length == 1) return populated.first[0].toUpperCase();
  return '${populated.first[0]}${populated.last[0]}'.toUpperCase();
}
