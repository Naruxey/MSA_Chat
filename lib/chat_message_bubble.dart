import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'main.dart' show AppColors, Pressable, slideRoute;
import 'chat_media_screens.dart' show ChatFullscreenImageViewer;

/// "3:07 PM" style time used on message bubbles and in last-seen text.
String formatChatTime(Timestamp? ts) {
  if (ts == null) return '';
  final dt = ts.toDate();
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

/// One chat message bubble: reply quote, text or photo, edited / time /
/// read ticks, and the reaction chips. Purely visual — everything it needs
/// is passed in, and reaction taps are reported through [onToggleReaction].
class ChatMessageBubble extends StatelessWidget {
  final bool isMine;
  final bool isDeleted;
  final String text;
  final Uint8List? imageBytes;
  final String? replyToText;
  final String? replyToSenderName;
  final Timestamp? sentAt;
  final bool isEdited;
  final bool isRead;
  final Map<String, int> reactionCounts;
  final bool iReacted;
  final String? myReaction;
  final void Function(String emoji) onToggleReaction;

  const ChatMessageBubble({
    super.key,
    required this.isMine,
    required this.isDeleted,
    required this.text,
    required this.imageBytes,
    required this.replyToText,
    required this.replyToSenderName,
    required this.sentAt,
    required this.isEdited,
    required this.isRead,
    required this.reactionCounts,
    required this.iReacted,
    required this.myReaction,
    required this.onToggleReaction,
  });

  @override
  Widget build(BuildContext context) {
    // Local copies so Dart can null-promote them inside the widget tree.
    final bytes = imageBytes;
    final replyText = replyToText;

    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.fieldFill,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine
              ? null
              : Border.all(color: AppColors.fieldBorder),
          boxShadow: [
            BoxShadow(
              color: (isMine ? AppColors.primary : Colors.black)
                  .withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyText != null && !isDeleted)
              Container(
                margin: EdgeInsets.only(bottom: 6),
                padding: EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: isMine
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
                        color: isMine
                            ? Colors.white
                            : AppColors.primary,
                      ),
                    ),
                    Text(
                      replyText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isMine
                            ? Colors.white70
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            if (bytes != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    slideRoute(ChatFullscreenImageViewer(imageBytes: bytes)),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => SizedBox(
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
                  color: isDeleted
                      ? (isMine
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey)
                      : (isMine ? Colors.white : AppColors.primaryDark),
                  fontSize: 15,
                  fontStyle:
                      isDeleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEdited && !isDeleted) ...[
                  Text(
                    'edited · ',
                    style: TextStyle(
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.grey,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                Text(
                  formatChatTime(sentAt),
                  style: TextStyle(
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.75)
                        : Colors.grey,
                    fontSize: 10,
                  ),
                ),
                if (isMine && !isDeleted) ...[
                  SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead
                        ? Color(0xFF63D4FF)
                        : Colors.white.withValues(alpha: 0.75),
                  ),
                ],
              ],
            ),
            if (reactionCounts.isNotEmpty && !isDeleted)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: reactionCounts.entries.map((e) {
                    final mine = iReacted && myReaction == e.key;
                    return Pressable(
                      onTap: () => onToggleReaction(e.key),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: mine
                              ? AppColors.accent.withValues(alpha: 0.25)
                              : (isMine
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : AppColors.background),
                          borderRadius: BorderRadius.circular(12),
                          border: mine
                              ? Border.all(color: AppColors.accent, width: 1)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(e.key, style: TextStyle(fontSize: 12)),
                            if (e.value > 1) ...[
                              SizedBox(width: 3),
                              Text(
                                '${e.value}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isMine
                                      ? Colors.white
                                      : AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
