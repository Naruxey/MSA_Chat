import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'main.dart' show AppColors, buildAppBar;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _stamp(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.day} ${_months[dt.month - 1]} ${dt.year} · $hour:$minute $period';
}

/// Admin-only list of recorded admin actions (currently: every time a
/// conversation was opened in the chat reader). Entries are written by
/// `logChatAccess` and the Firestore rules make them permanent — they can
/// be read by the admin but never edited or deleted by anyone.
class AdminActivityLogScreen extends StatelessWidget {
  static const _maxEntries = 100;

  const AdminActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('admin_logs')
        .orderBy('at', descending: true)
        .limit(_maxEntries)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBar(title: 'Activity Log'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load the activity log.\n'
                  'Check that the updated Firestore rules are published.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No activity recorded yet',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          final hitLimit = docs.length >= _maxEntries;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: docs.length + (hitLimit ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == docs.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Showing the latest $_maxEntries entries',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                );
              }
              return _LogTile(data: docs[index].data());
            },
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _LogTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final participants = List<String>.from(data['participants'] ?? const []);
    final rawNames = (data['participantNames'] as Map?) ?? {};
    final names = participants
        .map((uid) => (rawNames[uid] as String?) ?? 'Unknown')
        .toList();
    final at = (data['at'] as Timestamp?)?.toDate();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Icon(Icons.visibility_outlined,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Opened a conversation',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  names.isEmpty ? 'Unknown' : names.join('  ↔  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  at == null ? 'Just now' : _stamp(at),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
