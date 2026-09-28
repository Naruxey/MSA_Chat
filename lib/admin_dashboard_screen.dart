import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main.dart' show AppColors, AppRadius, appCardShadow, buildAppBar, slideRoute;
import 'login_screen.dart';
import 'presence.dart';
import 'account_list_screen.dart';
import 'fix_account_link_screen.dart';
import 'broadcasts_screen.dart';
import 'send_notification_screen.dart';

/// Landing screen for the single hardcoded admin account. Unlike the
/// staff/student MainScreen, admin has no tabs of their own — just a
/// menu into the account-management tools that already work across
/// both staff and student accounts (they query `users` directly with
/// no role filtering), plus the two broadcast screens.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<bool> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of the admin account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await _confirmLogout(context);
    if (!confirmed) return;
    if (!context.mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) await setUserOffline(uid);
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      slideRoute(const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBar(
        title: 'Admin Dashboard',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _Header(),
            const SizedBox(height: 24),
            const _StatsRow(),
            const SizedBox(height: 28),
            _SectionLabel('Accounts'),
            const SizedBox(height: 10),
            _DashboardTile(
              icon: Icons.link_rounded,
              title: 'Fix Account Link',
              subtitle: "Repair a mismatched ID-to-account link",
              onTap: () => Navigator.push(
                context,
                slideRoute(const FixAccountLinkScreen()),
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel('Announcements'),
            const SizedBox(height: 10),
            _DashboardTile(
              icon: Icons.campaign_outlined,
              title: 'Broadcasts',
              subtitle: 'View past announcements by sender',
              onTap: () => Navigator.push(
                context,
                slideRoute(const BroadcastsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _DashboardTile(
              icon: Icons.add_alert_outlined,
              title: 'Send Announcement',
              subtitle: 'Broadcast a message to everyone',
              onTap: () => Navigator.push(
                context,
                slideRoute(SendNotificationScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live-ish overview: how many students, staff and people online right now.
/// Uses Firestore count queries (cheap — no documents are downloaded) and
/// only refreshes when the screen opens or the refresh button is tapped.
/// "Online" is best-effort: someone who closes the browser tab abruptly can
/// stay marked online until their next login or app resume.
class _StatsRow extends StatefulWidget {
  const _StatsRow();

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  late Future<List<int>> _future = _load();

  Future<List<int>> _load() async {
    final users = FirebaseFirestore.instance.collection('users');
    final results = await Future.wait([
      users.where('role', isEqualTo: 'student').count().get(),
      users.where('role', isEqualTo: 'staff').count().get(),
      users.where('online', isEqualTo: true).count().get(),
    ]);
    return results.map((r) => r.count ?? 0).toList();
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _open(AccountFilter filter) async {
    await Navigator.push(context, slideRoute(AccountListScreen(filter: filter)));
    // Roles or online status may have changed while browsing.
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SectionLabel('Overview')),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Refresh',
              visualDensity: VisualDensity.compact,
              onPressed: _refresh,
            ),
          ],
        ),
        const SizedBox(height: 4),
        FutureBuilder<List<int>>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final failed = snapshot.hasError;
            String value(int i) {
              if (loading) return '…';
              if (failed || !snapshot.hasData) return '—';
              return snapshot.data![i].toString();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.school_outlined,
                        label: 'Students',
                        value: value(0),
                        onTap: () => _open(AccountFilter.students),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.badge_outlined,
                        label: 'Staff',
                        value: value(1),
                        onTap: () => _open(AccountFilter.staff),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.circle,
                        iconSize: 14,
                        label: 'Online now',
                        value: value(2),
                        onTap: () => _open(AccountFilter.online),
                      ),
                    ),
                  ],
                ),
                if (failed)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      'Could not load the counts. Tap refresh to try again.',
                      style: TextStyle(color: Colors.grey, fontSize: 12.5),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.iconSize = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: appCardShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary, size: iconSize),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.appBarGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: appCardShadow(opacity: 0.18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'You have full oversight of students and staff.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppColors.primaryDark.withValues(alpha: 0.55),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: appCardShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.grey, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.primary.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
