import 'package:flutter/material.dart';
import 'main.dart' show AppColors;

/// Strip above the text field while a message is being edited.
class ChatEditBanner extends StatelessWidget {
  final VoidCallback onCancel;

  const ChatEditBanner({super.key, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        border: Border(
          top: BorderSide(color: AppColors.fieldBorder),
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 16, color: AppColors.accent),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Editing message',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Strip above the text field while replying to a message.
class ChatReplyBanner extends StatelessWidget {
  final String senderName;
  final String text;
  final VoidCallback onCancel;

  const ChatReplyBanner({
    super.key,
    required this.senderName,
    required this.text,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        border: Border(
          top: BorderSide(color: AppColors.fieldBorder),
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $senderName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the text field when I have blocked the other person.
class ChatBlockedBanner extends StatelessWidget {
  final String otherUserName;

  const ChatBlockedBanner({super.key, required this.otherUserName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.fieldBorder)),
      ),
      child: Row(
        children: [
          Icon(Icons.block, size: 18, color: Colors.redAccent),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'You blocked $otherUserName. Unblock from their profile to send messages.',
              style: TextStyle(color: Colors.grey, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// The message input row: photo button, text field and send / save button.
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isUploadingImage;
  final bool isSending;
  final bool isEditing;
  final VoidCallback onPickImage;
  final VoidCallback onSend;
  final VoidCallback onTapField;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.isUploadingImage,
    required this.isSending,
    required this.isEditing,
    required this.onPickImage,
    required this.onSend,
    required this.onTapField,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.fieldBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: isUploadingImage
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  )
                : Icon(Icons.image_outlined, color: AppColors.primary),
            tooltip: 'Send a photo',
            onPressed: isUploadingImage ? null : onPickImage,
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              showCursor: true,
              minLines: 1,
              maxLines: 4,
              onTap: onTapField,
              style: TextStyle(color: AppColors.primaryDark),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: AppColors.fieldFill,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
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
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: isSending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(isEditing ? Icons.check : Icons.send,
                      color: Colors.white, size: 20),
              onPressed: isSending ? null : onSend,
            ),
          ),
        ],
      ),
    );
  }
}
