import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_notify.dart';
import 'main.dart' show AppColors;

/// Shortest password the app accepts for a changed password. Firebase itself
/// requires at least 6; raise this if registration asks for more.
const int kMinPasswordLength = 6;

/// Opens the "Change password" dialog and shows a confirmation once the
/// password has actually been changed.
Future<void> showChangePasswordDialog(BuildContext context) async {
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ChangePasswordDialog(),
  );
  if (changed == true && context.mounted) {
    showAppNotification(context, message: 'Password changed successfully.');
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _messageFor(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Your current password is incorrect.';
      case 'weak-password':
        return 'That new password is too weak. Try a longer one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'requires-recent-login':
        return 'For security, please log out, log in again, then try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      default:
        return 'Could not change password ($code).';
    }
  }

  Future<void> _submit() async {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    String? problem;
    if (current.isEmpty) {
      problem = 'Enter your current password.';
    } else if (next.length < kMinPasswordLength) {
      problem = 'New password must be at least $kMinPasswordLength characters.';
    } else if (next == current) {
      problem = 'New password must be different from the current one.';
    } else if (next != confirm) {
      problem = 'The new passwords do not match.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      setState(() => _error = 'You are not signed in properly. Please log in again.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Firebase requires proof of the current password before it will
      // change it, so sign in again silently first.
      final credential = EmailAuthProvider.credential(email: email, password: current);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(next);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _messageFor(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  InputDecoration _decoration(String label, bool visible, VoidCallback onToggle) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary),
      suffixIcon: IconButton(
        icon: Icon(
          visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: Colors.grey,
        ),
        onPressed: onToggle,
      ),
      filled: true,
      fillColor: AppColors.fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Change Password',
        style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentController,
                obscureText: !_showCurrent,
                enabled: !_saving,
                style: TextStyle(color: AppColors.primaryDark),
                decoration: _decoration('Current password', _showCurrent,
                    () => setState(() => _showCurrent = !_showCurrent)),
              ),
              SizedBox(height: 14),
              TextField(
                controller: _newController,
                obscureText: !_showNew,
                enabled: !_saving,
                style: TextStyle(color: AppColors.primaryDark),
                decoration: _decoration(
                    'New password', _showNew, () => setState(() => _showNew = !_showNew)),
              ),
              SizedBox(height: 14),
              TextField(
                controller: _confirmController,
                obscureText: !_showConfirm,
                enabled: !_saving,
                style: TextStyle(color: AppColors.primaryDark),
                decoration: _decoration('Confirm new password', _showConfirm,
                    () => setState(() => _showConfirm = !_showConfirm)),
                onSubmitted: (_) => _saving ? null : _submit(),
              ),
              if (_error != null) ...[
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text('Change'),
        ),
      ],
    );
  }
}
