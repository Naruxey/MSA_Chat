import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_constants.dart';

enum AppRole { student, staff, admin }

/// Resolves a signed-in user's role.
/// Admin is determined ONLY by matching the hardcoded UID —
/// never by anything stored in Firestore. This mirrors your
/// Firestore security rules, where isAdmin() also checks the UID directly.
Future<AppRole> resolveUserRole(String uid) async {
  if (uid == AppConstants.adminUid) {
    return AppRole.admin;
  }

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  final role = doc.data()?['role'];

  if (role == 'staff') return AppRole.staff;
  return AppRole.student; // default/fallback
}
