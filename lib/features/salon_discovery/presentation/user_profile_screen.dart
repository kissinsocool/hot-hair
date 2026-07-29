import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/top_snack_bar.dart';
import '../../auth/data/user_auth_repository.dart';
import '../../auth/data/user_session_store.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _authRepository = UserAuthRepository();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _gender = '保密';
  String _avatarUrl = '';
  XFile? _pendingAvatar;
  ImageProvider? _pendingAvatarImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = UserSessionStore.currentSession?.user;
    _nameController.text = user?.displayName ?? '';
    _phoneController.text = user?.phone ?? user?.account ?? '';
    _gender = user?.gender.isNotEmpty == true ? user!.gender : '保密';
    _avatarUrl = user?.avatarUrl ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  ImageProvider? _avatarImage() {
    if (_pendingAvatarImage != null) return _pendingAvatarImage;
    if (_avatarUrl.startsWith('data:image')) {
      final commaIndex = _avatarUrl.indexOf(',');
      if (commaIndex == -1) return null;
      try {
        return MemoryImage(base64Decode(_avatarUrl.substring(commaIndex + 1)));
      } catch (_) {
        return null;
      }
    }
    return _avatarUrl.isEmpty ? null : NetworkImage(_avatarUrl);
  }

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 76,
      maxWidth: 512,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _pendingAvatar = image;
      _pendingAvatarImage = MemoryImage(bytes);
    });
  }

  Future<void> _saveProfile() async {
    final displayName = _nameController.text.trim();
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (displayName.isEmpty) {
      _showMessage('请输入昵称');
      return;
    }
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      _showMessage('请输入有效的手机号');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final avatarUrl = _pendingAvatar == null
          ? _avatarUrl
          : await _authRepository.uploadAvatar(_pendingAvatar!);
      final session = await _authRepository.updateProfile(
        displayName: displayName,
        gender: _gender,
        phone: phone,
        avatarUrl: avatarUrl,
      );
      await UserSessionStore.save(session);
      _avatarUrl = session.user.avatarUrl;
      _pendingAvatar = null;
      _pendingAvatarImage = null;
      if (mounted) _showMessage('资料已保存');
    } catch (_) {
      if (mounted) _showMessage('保存失败，请稍后再试');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(topSnackBar(context, message));
  }

  @override
  Widget build(BuildContext context) {
    final avatarImage = _avatarImage();

    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPink,
        foregroundColor: AppTheme.white,
        title: const Text('用户资料'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.primaryPink.withOpacity(0.18),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.person,
                          color: AppTheme.primaryPink, size: 46)
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: AppTheme.primaryPink,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _pickAvatar,
                      child: const Padding(
                        padding: EdgeInsets.all(4.5),
                        child: Icon(Icons.photo_camera_outlined,
                            color: AppTheme.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentBeige),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('昵称', Icons.badge_outlined),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    items: const ['保密', '男', '女', '其他']
                        .map((gender) => DropdownMenuItem(
                              value: gender,
                              child: Text(gender),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _gender = value);
                    },
                    decoration: _inputDecoration('性别', Icons.wc_outlined),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration:
                        _inputDecoration('电话号码', Icons.phone_iphone_outlined),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isSaving ? '保存中' : '保存资料'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        foregroundColor: AppTheme.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
