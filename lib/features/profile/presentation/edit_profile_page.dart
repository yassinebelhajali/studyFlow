import 'package:flutter/material.dart';

import '../../../core/validation/form_validators.dart';
import 'profile_controller.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.controller});

  final ProfileController controller;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const _initialsAvatarOption = '__initials__';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _institutionController;
  late final TextEditingController _levelClassController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  late String? _avatarPath;
  bool _isSaving = false;
  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  static const _avatarOptions = <String>[
    'images/cc.jpg',
    'images/studyflow.png',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.controller.identity.fullName,
    );
    _emailController = TextEditingController(
      text: widget.controller.identity.email,
    );
    _institutionController = TextEditingController(
      text: widget.controller.identity.institution,
    );
    _levelClassController = TextEditingController(
      text: widget.controller.identity.levelClass,
    );
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _avatarPath = widget.controller.identity.avatarPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _institutionController.dispose();
    _levelClassController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFFF3F5F9),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _buildAvatarSection()),
              const SizedBox(height: 20),
              _buildLabel('Full Name'),
              _buildInput(
                controller: _nameController,
                validator: FormValidators.fullName,
              ),
              const SizedBox(height: 12),
              _buildLabel('Email'),
              _buildInput(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: FormValidators.email,
              ),
              const SizedBox(height: 12),
              _buildLabel('Institution'),
              _buildInput(
                controller: _institutionController,
                validator: (value) => FormValidators.requiredText(
                  value,
                  fieldName: 'institution',
                  minLength: 2,
                ),
              ),
              const SizedBox(height: 12),
              _buildLabel('Level / Class'),
              _buildInput(
                controller: _levelClassController,
                validator: (value) => FormValidators.requiredText(
                  value,
                  fieldName: 'level / class',
                  minLength: 2,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Text(
                'Change Password',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildLabel('Current Password'),
              _buildInput(
                controller: _currentPasswordController,
                obscureText: _hideCurrentPassword,
                validator: (value) {
                  if (!_isPasswordSectionFilled) {
                    return null;
                  }
                  return (value == null || value.isEmpty)
                      ? 'Enter current password'
                      : null;
                },
                suffix: IconButton(
                  onPressed: () {
                    setState(() {
                      _hideCurrentPassword = !_hideCurrentPassword;
                    });
                  },
                  icon: Icon(
                    _hideCurrentPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildLabel('New Password'),
              _buildInput(
                controller: _newPasswordController,
                obscureText: _hideNewPassword,
                validator: (value) {
                  if (!_isPasswordSectionFilled) {
                    return null;
                  }
                  return FormValidators.password(value);
                },
                suffix: IconButton(
                  onPressed: () {
                    setState(() {
                      _hideNewPassword = !_hideNewPassword;
                    });
                  },
                  icon: Icon(
                    _hideNewPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildLabel('Confirm New Password'),
              _buildInput(
                controller: _confirmPasswordController,
                obscureText: _hideConfirmPassword,
                validator: (value) {
                  if (!_isPasswordSectionFilled) {
                    return null;
                  }
                  return FormValidators.confirmPassword(
                    value,
                    _newPasswordController.text,
                  );
                },
                suffix: IconButton(
                  onPressed: () {
                    setState(() {
                      _hideConfirmPassword = !_hideConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _hideConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isPasswordSectionFilled {
    return _currentPasswordController.text.isNotEmpty ||
        _newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty;
  }

  Widget _buildAvatarSection() {
    final initials = _resolveInitials(_nameController.text);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              backgroundImage: _avatarPath != null
                  ? AssetImage(_avatarPath!)
                  : null,
              child: _avatarPath == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _pickAvatar,
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickAvatar,
          child: const Text(
            'Tap to change photo',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        suffixIcon: suffix,
      ),
    );
  }

  String _resolveInitials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'ST';
    }
    final first = parts.first[0].toUpperCase();
    if (parts.length == 1) {
      return first;
    }
    final second = parts.last[0].toUpperCase();
    return '$first$second';
  }

  Future<void> _pickAvatar() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Avatar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(_initialsAvatarOption),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      child: Text(
                        _resolveInitials(_nameController.text),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  for (final path in _avatarOptions)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(path),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundImage: AssetImage(path),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _avatarPath = selected == _initialsAvatarOption ? null : selected;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      await widget.controller.updateIdentity(
        fullName: _nameController.text,
        email: _emailController.text,
        institution: _institutionController.text,
        levelClass: _levelClassController.text,
        avatarPath: _avatarPath,
      );

      if (_isPasswordSectionFilled) {
        await widget.controller.changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isPasswordSectionFilled
                ? 'Profile and password updated successfully.'
                : 'Profile updated successfully.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
