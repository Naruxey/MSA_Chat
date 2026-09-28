import 'package:flutter/material.dart';
import 'package:msa_chat/group_screen.dart'; // MainScreen lives inside group_screen.dart
import 'role_service.dart';
import 'admin_dashboard_screen.dart';

Future<void> handlePostLoginNavigation(BuildContext context, String uid) async {
  final role = await resolveUserRole(uid);

  Widget destination;
  switch (role) {
    case AppRole.admin:
      destination = const AdminDashboardScreen();
      break;
    case AppRole.staff:
      destination = MainScreen(role: 'staff');
      break;
    case AppRole.student:
      destination = MainScreen(role: 'student');
      break;
  }

  if (context.mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }
}
