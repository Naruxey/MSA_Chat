import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_constants.dart';
import 'admin_chat_reader_screen.dart';
import 'app_notify.dart';
import 'main.dart' show AppColors, AppRadius, appCardShadow, buildAppBar, slideRoute;
import 'profile_screen.dart' show buildUserAvatar;

/// The groups a student can be moved between. Kept in sync with the list
/// in group_screen.dart — duplicated here since that one is file-private.
const _studentGroupOptions = [
  {'key': 'beginners', 'label': 'Beginners Group'},
  {'key': 'intermediate', 'label': 'Intermediate Group'},
  {'key': 'advance', 'label': 'Advance Group'},
];

/// Staff-only screen: shows everything on a single account (found by UID,
/// via the Fix Account Link tool) and lets staff edit it directly — name,
/// phone, bio, and, for students, which group they're in. No separate
/// "am I sure" step for text edits; group moves get a confirm dialog since
/// those affect where the student's chats live.
class UserRecordScreen extends StatefulWidget {
  final String uid;

  const UserRecordScreen({super.key, required this.uid});

  @override
  State<UserRecordScreen> createState() => _UserRecordScreenState();
}

class _UserRecordScreenState extends State<UserRecordScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _notFound = false;
  Map<String, dynamic>? _userData;
  String? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();

      if (!doc.exists) {
        if (!mounted) return;
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }

      final data = doc.data()!;
      if (!mounted) return;
      setState(() {
        _userData = data;
        _nameController.text = (data['name'] as String?) ?? '';
        _phoneController.text = (data['phone'] as String?) ?? '';
        _bioController.text = (data['bio'] as String?) ?? '';
        _selectedGroup = data['group'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppNotification(context, message: 'Could not load account: $e', isError: true);
    }
  }

  bool get _isStaffAccount => (_userData?['role'] as String?) == 'staff';

  /// Only the admin sees (and can use) the password-reset button.
  bool get _viewerIsAdmin =>
      FirebaseAuth.instance.currentUser?.uid == AppConstants.adminUid;

  bool get _isDisabled => _userData?['disabled'] == true;

  bool _togglingDisabled = false;

  /// Admin-only: disable (or re-enable) an account. A disabled person is
  /// signed out, can't log back in, and can't send or read messages. Their
  /// data is kept, and enabling them again restores everything.
  Future<void> _toggleDisabled() async {
    final name = _nameController.text.trim().isEmpty
        ? 'this account'
        : _nameController.text.trim();
    final disabling = !_isDisabled;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(disabling ? 'Disable account?' : 'Enable account?'),
        content: Text(
          disabling
              ? '$name will be signed out and won\'t be able to log in or '
                  'send messages until you enable the account again. Their '
                  'messages and details are kept.'
              : '$name will be able to log in and use the app again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              disabling ? 'Disable' : 'Enable',
              style: TextStyle(
                color: disabling ? Colors.redAccent : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final updates = <String, dynamic>{
      'disabled': disabling,
      if (disabling) 'online': false,
    };

    setState(() => _togglingDisabled = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update(updates);

      if (!mounted) return;
      setState(() => _userData = {...?_userData, ...updates});
      showAppNotification(
        context,
        message: disabling ? '$name has been disabled' : '$name has been enabled',
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showAppNotification(
        context,
        message: 'Could not update the account (${e.code}). Check Firestore rules.',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      showAppNotification(context, message: 'Something went wrong: $e', isError: true);
    } finally {
      if (mounted) setState(() => _togglingDisabled = false);
    }
  }

  bool _changingRole = false;

  /// Admin-only: promote a student to staff, or move a staff member back
  /// to student (the admin picks which level they go into). The ID number
  /// stays exactly as it was issued — only role, level and group change.
  Future<void> _changeRole() async {
    final data = _userData;
    if (data == null) return;

    final name = _nameController.text.trim().isEmpty
        ? 'this account'
        : _nameController.text.trim();
    final makingStaff = !_isStaffAccount;

    String pickedLevel = _studentGroupOptions.first['key']!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(makingStaff ? 'Make staff?' : 'Make student?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                makingStaff
                    ? '$name will become a staff member and move to the Staff '
                        'Group. They will be able to send announcements and '
                        'manage students.'
                    : '$name will become a student and lose staff tools. '
                        'Choose the group they should join:',
              ),
              if (!makingStaff) ...[
                const SizedBox(height: 12),
                DropdownButton<String>(
                  isExpanded: true,
                  value: pickedLevel,
                  items: _studentGroupOptions
                      .map((g) => DropdownMenuItem(
                            value: g['key'],
                            child: Text(g['label']!),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => pickedLevel = v);
                  },
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'They need to log out and back in for this to take effect.',
                style: TextStyle(color: Colors.grey, fontSize: 12.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Confirm',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final updates = <String, dynamic>{
      'role': makingStaff ? 'staff' : 'student',
      'group': makingStaff ? 'staff' : pickedLevel,
      'level': makingStaff ? null : pickedLevel,
    };

    setState(() => _changingRole = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update(updates);

      if (!mounted) return;
      setState(() {
        _userData = {...?_userData, ...updates};
        _selectedGroup = updates['group'] as String?;
      });
      showAppNotification(
        context,
        message: makingStaff ? '$name is now staff' : '$name is now a student',
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showAppNotification(
        context,
        message: 'Could not change role (${e.code}). Check Firestore rules.',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      showAppNotification(context, message: 'Something went wrong: $e', isError: true);
    } finally {
      if (mounted) setState(() => _changingRole = false);
    }
  }

  bool _sendingReset = false;

  Future<void> _sendPasswordReset() async {
    final email = (_userData?['email'] as String?)?.trim() ?? '';
    if (email.isEmpty) {
      showAppNotification(
        context,
        message: 'This account has no email on record',
        isError: true,
      );
      return;
    }

    final name = _nameController.text.trim().isEmpty
        ? 'this account'
        : _nameController.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send password reset?'),
        content: Text(
          'A password reset link will be emailed to $email so $name can '
          'choose a new password. Their current password keeps working '
          'until they use the link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Send',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sendingReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      showAppNotification(context, message: 'Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showAppNotification(
        context,
        message: 'Could not send the email (${e.code})',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      showAppNotification(context, message: 'Something went wrong: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  bool get _groupChanged =>
      !_isStaffAccount && _selectedGroup != (_userData?['group'] as String?);

  Future<void> _save() async {
    final updates = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'bio': _bioController.text.trim(),
    };

    if (_groupChanged) {
      final name = _nameController.text.trim().isEmpty
          ? 'this student'
          : _nameController.text.trim();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Move this student?'),
          content: Text(
            '$name will be moved to ${_labelForGroupKey(_selectedGroup)}. '
            'They\'ll see that group\'s chats the next time they open the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Move',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      updates['group'] = _selectedGroup;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update(updates);

      if (!mounted) return;
      setState(() {
        _userData = {...?_userData, ...updates};
      });
      showAppNotification(context, message: 'Account updated');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showAppNotification(
        context,
        message: 'Could not save (${e.code}). Check Firestore rules.',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      showAppNotification(context, message: 'Something went wrong: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _labelForGroupKey(String? key) {
    final match = _studentGroupOptions.firstWhere(
      (g) => g['key'] == key,
      orElse: () => const {'label': 'Unknown Group'},
    );
    return match['label']!;
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBar(title: 'Account Details'),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _notFound
                ? Center(
                    child: Text(
                      'This account no longer exists.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          children: [
                            _avatar(),
                            const SizedBox(height: 24),
                            _readOnlyCard(),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _nameController,
                              style: TextStyle(color: AppColors.primaryDark),
                              decoration: _decoration('Name', Icons.person_outline),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(color: AppColors.primaryDark),
                              decoration: _decoration('Phone number', Icons.phone_outlined),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _bioController,
                              maxLines: 3,
                              maxLength: 150,
                              style: TextStyle(color: AppColors.primaryDark),
                              decoration: _decoration('Bio', Icons.info_outline),
                            ),
                            const SizedBox(height: 8),
                            if (!_isStaffAccount) _groupPicker(),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 4,
                                  shadowColor: AppColors.primary.withValues(alpha: 0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            if (_viewerIsAdmin) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _sendingReset ? null : _sendPasswordReset,
                                  icon: _sendingReset
                                      ? SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(Icons.lock_reset_rounded,
                                          color: AppColors.primary),
                                  label: Text(
                                    'Send Password Reset Email',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _changingRole ? null : _changeRole,
                                  icon: _changingRole
                                      ? SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(Icons.swap_horiz_rounded,
                                          color: AppColors.primary),
                                  label: Text(
                                    _isStaffAccount
                                        ? 'Make Student'
                                        : 'Make Staff',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _togglingDisabled ? null : _toggleDisabled,
                                  icon: _togglingDisabled
                                      ? SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            color: _isDisabled
                                                ? AppColors.primary
                                                : Colors.redAccent,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          _isDisabled
                                              ? Icons.check_circle_outline
                                              : Icons.block_rounded,
                                          color: _isDisabled
                                              ? AppColors.primary
                                              : Colors.redAccent,
                                        ),
                                  label: Text(
                                    _isDisabled ? 'Enable Account' : 'Disable Account',
                                    style: TextStyle(
                                      color: _isDisabled
                                          ? AppColors.primary
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(
                                      color: _isDisabled
                                          ? AppColors.primary
                                          : Colors.redAccent,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    slideRoute(
                                      AdminChatReaderScreen(
                                        onlyUserId: widget.uid,
                                        onlyUserName:
                                            (_userData?['name'] as String?) ?? 'This user',
                                      ),
                                    ),
                                  ),
                                  icon: Icon(Icons.forum_outlined, color: AppColors.primary),
                                  label: Text(
                                    'View Chats',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _avatar() {
    final name = (_userData?['name'] as String?) ?? '';
    return buildUserAvatar(userData: _userData, fallbackName: name, radius: 40);
  }

  Widget _readOnlyCard() {
    final email = _userData?['email'] as String? ?? '';
    final idNumber = _userData?['id_number'] as String? ?? '';
    final role = _userData?['role'] as String? ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Email', email),
          _infoRow('ID Number', idNumber),
          _infoRow('Role', role == 'staff' ? 'Staff' : 'Student'),
          _infoRow('Status', _isDisabled ? 'Disabled' : 'Active'),
          if (!_isStaffAccount) _infoRow('Current Group', _labelForGroupKey(_userData?['group'] as String?)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupPicker() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: appCardShadow(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: _selectedGroup,
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: 'Group',
            labelStyle: TextStyle(color: Colors.grey),
          ),
          dropdownColor: AppColors.surface,
          style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
          items: _studentGroupOptions
              .map((g) => DropdownMenuItem(
                    value: g['key'],
                    child: Text(g['label']!),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedGroup = value),
        ),
      ),
    );
  }
}
