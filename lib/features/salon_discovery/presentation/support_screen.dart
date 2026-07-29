import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/top_snack_bar.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, this.onSubmit});

  final Future<void> Function(String problem, String contact)? onSubmit;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemController = TextEditingController();
  final _contactController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _problemController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);
    try {
      final problem = _problemController.text.trim();
      final contact = _contactController.text.trim();
      if (widget.onSubmit != null) {
        await widget.onSubmit!(problem, contact);
      } else {
        await ApiClient().request(
          '/support-messages',
          method: 'POST',
          data: {'problem': problem, 'contact': contact},
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        topSnackBar(context, '反馈已提交，我们会尽快与您联系'),
      );
      _problemController.clear();
      _contactController.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        topSnackBar(
          context,
          ApiClient.errorMessage(error, fallback: '提交失败，请稍后重试'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPink,
        foregroundColor: AppTheme.white,
        title: const Text('平台客服'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _problemController,
                minLines: 6,
                maxLines: 10,
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                decoration: _inputDecoration(
                  label: '请描述您遇到的问题',
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    value?.trim().isEmpty == false ? null : '请描述您遇到的问题',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: _inputDecoration(
                  label: '联系方式',
                ),
                validator: (value) =>
                    value?.trim().isEmpty == false ? null : '请输入联系方式',
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? '提交中...' : '提交'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: AppTheme.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accentBeige),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accentBeige),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppTheme.primaryPink,
          width: 1.4,
        ),
      ),
    );
  }
}
