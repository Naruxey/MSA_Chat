import 'package:flutter/material.dart';

import 'main.dart' show AppColors, buildAppBar;

/// Plain-language privacy notice, opened from the registration form.
/// Static text only — nothing here reads or writes any data.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBar(title: 'Privacy Notice'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: const [
            _Intro(),
            _Section(
              icon: Icons.storage_outlined,
              title: 'What MSA_Chat stores',
              body:
                  'Your name, academy ID, email address, phone number and bio '
                  '(if you add them), your profile photo, your group, whether '
                  "you're online and when you were last seen, and everything "
                  'you send: messages and photos.',
            ),
            _Section(
              icon: Icons.visibility_outlined,
              title: 'Who can see your messages',
              body:
                  'Your conversations are visible to you and the person you '
                  'are chatting with. The academy administrator can also open '
                  'and read any conversation to deal with problems or '
                  'misuse. Messages are not end-to-end encrypted.',
            ),
            _Section(
              icon: Icons.history_rounded,
              title: 'Admin access is recorded',
              body:
                  'Every time the administrator opens a conversation, the '
                  'time and the people in it are written to a permanent log '
                  'that cannot be edited or deleted. Opening a conversation '
                  'does not mark your messages as read or show up as '
                  'activity to you or the other person.',
            ),
            _Section(
              icon: Icons.groups_outlined,
              title: 'What staff can see and do',
              body:
                  'Staff can view student profiles, edit basic details '
                  '(name, phone, bio, group), and send announcements to '
                  'everyone. Staff cannot read private conversations.',
            ),
            _Section(
              icon: Icons.delete_outline,
              title: 'Deleting messages',
              body:
                  'When you delete a message, its text is removed and the '
                  'chat shows "This message was deleted". Photos you delete '
                  'are hidden from the chat in the same way.',
            ),
            _Section(
              icon: Icons.lock_outline,
              title: 'Your account',
              body:
                  'The administrator can disable an account, change a '
                  "person's role between student and staff, and send a "
                  'password reset email. Please keep your password private '
                  'and never share it, even with staff.',
            ),
            _Section(
              icon: Icons.help_outline,
              title: 'Questions',
              body:
                  'If you have a question about your information, ask the '
                  'academy administrator.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'MSA_Chat is the messaging app of Muhab Skills Academy. This notice '
        'explains, in plain words, what the app keeps and who can see it, '
        'so you can decide before creating an account.',
        style: TextStyle(
          fontSize: 14.5,
          height: 1.5,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Section({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
