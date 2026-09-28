import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'main.dart' show AppColors, AppRadius, appCardShadow, buildAppBar, slideRoute;
import 'profile_screen.dart' show buildUserAvatar;
import 'user_record_screen.dart';

enum AccountFilter { students, staff, online }

/// Admin list of accounts for one of the dashboard's Overview boxes:
/// every student, every staff member, or everyone marked online right now.
/// Tapping a person opens the same Account Details screen used elsewhere.
class AccountListScreen extends StatefulWidget {
  final AccountFilter filter;

  const AccountListScreen({super.key, required this.filter});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  // Built once (not inside build) so the Firestore listener isn't torn
  // down and reopened on every rebuild or keystroke.
  late final Stream<QuerySnapshot> _stream = _buildStream();

  Stream<QuerySnapshot> _buildStream() {
    final users = FirebaseFirestore.instance.collection('users');
    switch (widget.filter) {
      case AccountFilter.students:
        return users.where('role', isEqualTo: 'student').snapshots();
      case AccountFilter.staff:
        return users.where('role', isEqualTo: 'staff').snapshots();
      case AccountFilter.online:
        return users.where('online', isEqualTo: true).snapshots();
    }
  }

  String get _title {
    switch (widget.filter) {
      case AccountFilter.students:
        return 'Students';
      case AccountFilter.staff:
        return 'Staff';
      case AccountFilter.online:
        return 'Online Now';
    }
  }

  String get _emptyText {
    switch (widget.filter) {
      case AccountFilter.students:
        return 'No students yet';
      case AccountFilter.staff:
        return 'No staff accounts yet';
      case AccountFilter.online:
        return 'Nobody is online right now';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _labelForGroup(String? group) {
    switch (group) {
      case 'beginners':
        return 'Beginners Group';
      case 'intermediate':
        return 'Intermediate Group';
      case 'advance':
        return 'Advance Group';
      case 'staff':
        return 'Staff Group';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBar(title: _title),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: AppColors.primaryDark),
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: AppColors.fieldFill,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.fieldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.fieldBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            Expanded(child: _list()),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Something went wrong loading accounts.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final needle = _query.toLowerCase();
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] as String? ?? '').toLowerCase();
          return needle.isEmpty || name.contains(needle);
        }).toList()
          ..sort((a, b) {
            final an = ((a.data() as Map<String, dynamic>)['name'] as String? ?? '')
                .toLowerCase();
            final bn = ((b.data() as Map<String, dynamic>)['name'] as String? ?? '')
                .toLowerCase();
            return an.compareTo(bn);
          });

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _query.isEmpty ? _emptyText : 'No accounts match "$_query"',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          itemCount: docs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                child: Text(
                  docs.length == 1 ? '1 account' : '${docs.length} accounts',
                  style: const TextStyle(color: Colors.grey, fontSize: 12.5),
                ),
              );
            }

            final doc = docs[index - 1];
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] as String?) ?? 'Unknown';
            final role = (data['role'] as String?) ?? '';
            final isOnline = data['online'] == true;
            final groupLabel = role == 'staff'
                ? 'Staff'
                : _labelForGroup(data['group'] as String?);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: appCardShadow(),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: buildUserAvatar(userData: data, fallbackName: name),
                  title: Text(
                    name,
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    data['disabled'] == true
                        ? '$groupLabel • Disabled'
                        : groupLabel,
                    style: TextStyle(
                      color: data['disabled'] == true
                          ? Colors.redAccent
                          : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOnline) ...[
                        const Icon(Icons.circle, color: Colors.green, size: 10),
                        const SizedBox(width: 10),
                      ],
                      Icon(Icons.chevron_right, color: AppColors.primary),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    slideRoute(UserRecordScreen(uid: doc.id)),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
