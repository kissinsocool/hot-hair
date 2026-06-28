import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/top_snack_bar.dart';
import '../data/user_auth_repository.dart';

class AuthScreen extends StatefulWidget {
  final ValueChanged<ClientAuthSession> onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final UserAuthRepository _repository = UserAuthRepository();
  bool _isRequestingCode = false;
  bool _isSubmitting = false;
  bool _codeSent = false;
  String? _debugCode;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _phone => _phoneController.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _requestCode() async {
    if (!_validatePhone()) return;

    setState(() {
      _isRequestingCode = true;
      _debugCode = null;
    });
    try {
      final debugCode = await _repository.requestSmsCode(phone: _phone);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _debugCode = debugCode;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        topSnackBar(context, '验证码已发送'),
      );
    } catch (error) {
      _showError(error, fallback: '验证码发送失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isRequestingCode = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final session = await _repository.verifySmsCode(
        phone: _phone,
        code: _codeController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        topSnackBar(context, '登录成功'),
      );
      widget.onAuthenticated(session);
    } catch (error) {
      _showError(error, fallback: '登录失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _validatePhone() {
    final phone = _phone;
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        topSnackBar(context, '请输入有效的手机号'),
      );
      return false;
    }
    return true;
  }

  void _showError(Object error, {required String fallback}) {
    final message = error is DioException
        ? (error.response?.data is Map
            ? error.response?.data['message']?.toString()
            : null)
        : null;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      topSnackBar(context, message ?? fallback),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textDark),
        title: Text(
          '手机号登录',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return SingleChildScrollView(
              padding: EdgeInsets.all(isWide ? 16 : 10),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _buildIntroPanel()),
                            const SizedBox(width: 28),
                            Expanded(child: _buildFormPanel()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildIntroPanel(),
                            const SizedBox(height: 20),
                            _buildFormPanel(),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntroPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          AppImages.placeholder(
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.28),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hot Pepper Beauty',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '输入手机号，通过验证码快速注册或登录。',
                  style: TextStyle(
                    color: AppTheme.white.withOpacity(0.92),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '手机号一键登录',
              style: TextStyle(
                color: AppTheme.textDark,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '未注册手机号会自动创建账号。',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                label: '手机号',
                icon: Icons.phone_iphone_outlined,
              ),
              validator: (value) {
                final phone = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
                  return '请输入有效的手机号';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: _inputDecoration(
                      label: '验证码',
                      icon: Icons.verified_outlined,
                    ),
                    validator: (value) {
                      if (!RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')) {
                        return '请输入6位验证码';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Center(
                  child: SizedBox(
                    width: 118,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isRequestingCode ? null : _requestCode,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink.withOpacity(0.08),
                        foregroundColor: AppTheme.primaryPink,
                        disabledForegroundColor: Colors.grey[500],
                        side: BorderSide(
                          color: _isRequestingCode
                              ? Colors.grey.shade300
                              : AppTheme.primaryPink.withOpacity(0.42),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: _isRequestingCode
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryPink,
                              ),
                            )
                          : Text(
                              _codeSent ? '重新获取' : '获取验证码',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            if (_debugCode != null) ...[
              const SizedBox(height: 10),
              Text(
                '开发验证码：$_debugCode',
                style: TextStyle(color: AppTheme.primaryPink, fontSize: 13),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '登录 / 注册',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 7.5),
      filled: true,
      fillColor: AppTheme.bgCream,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.accentBeige),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.accentBeige),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primaryPink, width: 1.4),
      ),
    );
  }
}
