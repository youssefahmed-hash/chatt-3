import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/api_service.dart';

/// Change the current user's password. Works on all platforms — validates the
/// three fields locally, then verifies the current password on the server.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final current = _currentCtrl.text;
    final newPass = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    setState(() {
      _error = null;
      _success = null;
    });

    if (current.isEmpty) {
      setState(() => _error = l10n.passwordRequired);
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = l10n.passwordTooShort);
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = l10n.passwordMismatch);
      return;
    }

    setState(() => _loading = true);

    try {
      await ApiService.changePassword(current, newPass);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = l10n.passwordChangedSuccess;
      });
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _loading = false;
        _error = msg.contains('Current password is incorrect')
            ? l10n.currentPasswordWrong
            : l10n.passwordChangeError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePassword)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _currentCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: l10n.currentPassword,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _newCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: l10n.newPassword,
              prefixIcon: const Icon(Icons.lock_reset),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: l10n.confirmNewPassword,
              prefixIcon: const Icon(Icons.verified_user_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              label: Text(_obscure ? l10n.show : l10n.hide),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ],
          if (_success != null) ...[
            const SizedBox(height: 8),
            Text(
              _success!,
              style: TextStyle(color: theme.colorScheme.secondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.changePassword),
            ),
          ),
        ],
      ),
    );
  }
}