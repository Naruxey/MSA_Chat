import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'main.dart' show AppColors, buildAppBar, slideRoute;

/// Labels for the group keys stored in `participantGroups` on each chat.
const _groupLabels = {
  'beginners': 'Beginners',
  'intermediate': 'Intermediate',
  'advance': 'Advance',
  'staff': 'Staff',
};

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _timeOf(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _dateOf(DateTime dt) => '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Short stamp for the conversation list: time if today, otherwise date.
String _listStamp(Timestamp? ts) {
  if (ts == null) return '';
  final dt = ts.toDate();
  return _sameDay(dt, DateTime.now()) ? _timeOf(dt) : _dateOf(dt);
}

/// Records that the admin opened a conversation. Written to `admin_logs`
/// (admin-only in the Firestore rules, never editable or deletable).
/// Fire-and-forget: if the write fails the chat still opens, so a logging
/// hiccup never blocks the admin — but a failure is easy to spot because
/// the entry will simply be missing from the Activity Log.
Future<void> logChatAccess({
  required String chatId,
  required List<String> participants,
  required Map<String, String> names,
}) async {
  final adminId = FirebaseAuth.instance.currentUser?.uid;
  if (adminId == null) return;
  try {
    await FirebaseFirestore.instance.collection('admin_logs').add({
      'adminId': adminId,
      'action': 'open_chat',
      'chatId': chatId,
      'participants': participants,
      'participantNames': names,
      'at': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // Intentionally silent — see note above.
  }
}

/// Admin-only, READ-ONLY view of every conversation in the app.
///
/// Every chat in MSA_Chat is a 1-on-1 document in `chats` (there are no
/// separate group-room chats — groups are just lists of members), so this
/// one list covers everything. It can be filtered by group (using each
/// chat's `participantGroups`) and searched by participant name.
///
/// When [onlyUserId] is set, only that person's conversations are shown
/// (used by the "View Chats" button on the account details screen).
///
/// This screen never writes anything: it does not mark messages as read,
/// set typing indicators, or touch the chat documents in any way, so
/// opening a conversation is invisible to the people in it.
class AdminChatReaderScreen extends StatefulWidget {
  final String? onlyUserId;
  final String? onlyUserName;

  const AdminChatReaderScreen({super.key, this.onlyUserId, this.onlyUserName});

  @override
  State<AdminChatReaderScreen> createState() => _AdminChatReaderScreenState();
}

class _AdminChatReaderScreenState extends State<AdminChatReaderScreen> {
  static const _maxChats = 300;

  final _searchController = TextEditingController();
  String _query = '';
  String? _groupFilter; // null = all groups

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    final chats = FirebaseFirestore.instance.collection('chats');
    if (widget.onlyUserId != null) {
      // One person's chats. No orderBy here so no composite index is
      // needed — sorting happens below in Dart.
      _stream = chats
          .where('participants', arrayContains: widget.onlyUserId)
          .snapshots();
    } else {
      _stream = chats
          .orderBy('lastMessageAt', descending: true)
          .limit(_maxChats)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _filterChip(String? key, String label) {
    final selected = _groupFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.primaryDark,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.fieldFill,
        side: BorderSide(color: AppColors.fieldBorder),
        onSelected: (_) => setState(() => _groupFilter = key),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.onlyUserName != null
        ? "${widget.onlyUserName}'s Chats"
        : 'All Conversations';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBar(title: title),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: TextStyle(color: AppColors.primaryDark),
              decoration: InputDecoration(
                hintText: 'Search by name',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: AppColors.fieldFill,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.fieldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              children: [
                _filterChip(null, 'All'),
                for (final e in _groupLabels.entries) _filterChip(e.key, e.value),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load conversations.\n'
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

                var docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(
                  snapshot.data?.docs ?? [],
                );

                // Chats created only by a pin/mute tap have no messages.
                docs = docs
                    .where((d) => d.data()['lastMessageAt'] != null)
                    .toList();

                if (widget.onlyUserId != null) {
                  docs.sort((a, b) {
                    final ta = a.data()['lastMessageAt'] as Timestamp;
                    final tb = b.data()['lastMessageAt'] as Timestamp;
                    return tb.compareTo(ta);
                  });
                }

                final filtered = docs.where((d) {
                  final data = d.data();
                  final names = _namesOf(data).values;
                  if (_query.isNotEmpty &&
                      !names.any((n) => n.toLowerCase().contains(_query))) {
                    return false;
                  }
                  if (_groupFilter != null) {
                    final groups = _groupsOf(data).values;
                    if (!groups.contains(_groupFilter)) return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      docs.isEmpty
                          ? 'No conversations yet'
                          : 'No conversations match',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                final hitLimit =
                    widget.onlyUserId == null && docs.length >= _maxChats;

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length + (hitLimit ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == filtered.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Showing the $_maxChats most recent conversations. '
                          'Use search to find older ones.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      );
                    }
                    return _ConversationTile(doc: filtered[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, String> _namesOf(Map<String, dynamic> data) {
  final raw = (data['participantNames'] as Map?) ?? {};
  return raw.map((k, v) => MapEntry(k as String, (v as String?) ?? 'Unknown'));
}

Map<String, String> _groupsOf(Map<String, dynamic> data) {
  final raw = (data['participantGroups'] as Map?) ?? {};
  return raw.map((k, v) => MapEntry(k as String, (v as String?) ?? ''));
}

class _ConversationTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _ConversationTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final participants = List<String>.from(data['participants'] ?? const []);
    final names = _namesOf(data);
    final groups = _groupsOf(data);
    final lastMessage = (data['lastMessage'] as String?) ?? '';
    final lastAt = data['lastMessageAt'] as Timestamp?;
    final lastSenderId = data['lastSenderId'] as String?;

    final nameA = participants.isNotEmpty ? (names[participants[0]] ?? 'Unknown') : 'Unknown';
    final nameB = participants.length > 1 ? (names[participants[1]] ?? 'Unknown') : 'Unknown';
    final groupA = _groupLabels[groups[participants.isNotEmpty ? participants[0] : '']] ?? '';
    final groupB = _groupLabels[groups[participants.length > 1 ? participants[1] : '']] ?? '';

    final lastSenderName = lastSenderId == null ? null : names[lastSenderId];

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          logChatAccess(chatId: doc.id, participants: participants, names: names);
          Navigator.push(
            context,
            slideRoute(
              AdminChatMessagesScreen(
                chatId: doc.id,
                participants: participants,
                names: names,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(Icons.forum_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$nameA  ↔  $nameB',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (groupA.isNotEmpty || groupB.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [groupA, groupB].where((g) => g.isNotEmpty).join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      lastSenderName != null ? '$lastSenderName: $lastMessage' : lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _listStamp(lastAt),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only transcript of one conversation. No input box, no read
/// receipts, no typing indicator — nothing here writes to Firestore.
class AdminChatMessagesScreen extends StatelessWidget {
  static const _maxMessages = 300;

  final String chatId;
  final List<String> participants;
  final Map<String, String> names;

  const AdminChatMessagesScreen({
    super.key,
    required this.chatId,
    required this.participants,
    required this.names,
  });

  String _nameOf(String uid) => names[uid] ?? 'Unknown';

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(_maxMessages)
        .snapshots();

    final title = participants.map(_nameOf).join(' & ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBar(title: title.isEmpty ? 'Conversation' : title),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppColors.primary.withValues(alpha: 0.10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_outlined, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Admin view · read-only',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load messages.',
                      style: TextStyle(color: Colors.grey.shade600),
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
                      'No messages in this conversation',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                final hitLimit = docs.length >= _maxMessages;

                return ListView.builder(
                  reverse: true, // newest at the bottom, like the real chat
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  itemCount: docs.length + (hitLimit ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == docs.length) {
                      // Top of the (reversed) list: older messages exist.
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Showing the latest $_maxMessages messages',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      );
                    }

                    final data = docs[index].data();
                    final sentAt = (data['sentAt'] as Timestamp?)?.toDate();

                    // Date chip above the first message of each day. The
                    // list is newest-first, so the "previous" message in
                    // time is the next index.
                    var showDate = false;
                    if (sentAt != null) {
                      if (index == docs.length - 1) {
                        showDate = true;
                      } else {
                        final older =
                            (docs[index + 1].data()['sentAt'] as Timestamp?)?.toDate();
                        showDate = older == null || !_sameDay(older, sentAt);
                      }
                    }

                    return Column(
                      children: [
                        if (showDate) _DateChip(label: _dateOf(sentAt!)),
                        _MessageBubble(
                          data: data,
                          senderName: _nameOf((data['senderId'] as String?) ?? ''),
                          isFirstParticipant: participants.isNotEmpty &&
                              data['senderId'] == participants.first,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final String senderName;
  final bool isFirstParticipant;

  const _MessageBubble({
    required this.data,
    required this.senderName,
    required this.isFirstParticipant,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted = data['deleted'] == true;
    final isEdited = data['edited'] == true;
    final text = isDeleted ? '' : ((data['text'] as String?) ?? '');
    final sentAt = (data['sentAt'] as Timestamp?)?.toDate();
    final replyToText = data['replyToText'] as String?;
    final replyToSenderName = data['replyToSenderName'] as String?;

    Uint8List? imageBytes;
    final imageBase64 = isDeleted ? null : data['imageBase64'] as String?;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        imageBytes = base64Decode(imageBase64);
      } catch (_) {
        imageBytes = null;
      }
    }

    // Reactions: uid -> emoji. Collapse identical emoji into "👍 2".
    final reactions = (data['reactions'] as Map?) ?? {};
    final reactionCounts = <String, int>{};
    for (final emoji in reactions.values) {
      if (emoji is String) {
        reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
      }
    }

    // First participant on the right (teal), second on the left.
    final mine = isFirstParticipant;
    final fg = mine ? Colors.white : AppColors.primaryDark;
    final subtle = mine ? Colors.white.withValues(alpha: 0.7) : Colors.grey;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 4, bottom: 2),
            child: Text(
              senderName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? AppColors.primary : AppColors.fieldFill,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
              border: mine ? null : Border.all(color: AppColors.fieldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (replyToText != null && !isDeleted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: mine
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: mine
                              ? Colors.white.withValues(alpha: 0.6)
                              : AppColors.primary,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          replyToSenderName ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: mine ? Colors.white : AppColors.primary,
                          ),
                        ),
                        Text(
                          replyToText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: subtle),
                        ),
                      ],
                    ),
                  ),
                if (imageBytes != null)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      slideRoute(_ImageViewer(bytes: imageBytes!)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        imageBytes,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 200,
                          height: 200,
                          child: Center(child: Icon(Icons.broken_image_outlined)),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    isDeleted ? 'This message was deleted' : text,
                    style: TextStyle(
                      color: isDeleted ? subtle : fg,
                      fontSize: 15,
                      fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${isEdited && !isDeleted ? 'edited · ' : ''}'
                  '${sentAt == null ? '' : _timeOf(sentAt)}',
                  style: TextStyle(color: subtle, fontSize: 10),
                ),
              ],
            ),
          ),
          if (reactionCounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Text(
                reactionCounts.entries
                    .map((e) => e.value > 1 ? '${e.key} ${e.value}' : e.key)
                    .join('  '),
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final Uint8List bytes;

  const _ImageViewer({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.memory(bytes),
        ),
      ),
    );
  }
}
