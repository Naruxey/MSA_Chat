import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'main.dart' show AppColors, buildAppBar, slideRoute;

/// All photos shared in this chat, newest first, in a grid — tapping one
/// opens it full-screen. Reuses the same messages subcollection instead of
/// a separate media index, since a single chat's photo count is small
/// enough to filter client-side.
class ChatMediaGalleryScreen extends StatelessWidget {
  final String chatId;

  const ChatMediaGalleryScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildAppBar(title: 'Shared Photos'),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final imageDocs = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['deleted'] == true) return false;
            final img = data['imageBase64'] as String?;
            return img != null && img.isNotEmpty;
          }).toList();

          if (imageDocs.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 56,
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No photos shared yet',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: EdgeInsets.all(10),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: imageDocs.length,
            itemBuilder: (context, index) {
              final data = imageDocs[index].data() as Map<String, dynamic>;
              Uint8List? bytes;
              try {
                bytes = base64Decode(data['imageBase64'] as String);
              } catch (_) {
                bytes = null;
              }
              if (bytes == null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: AppColors.fieldFill,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey,
                    ),
                  ),
                );
              }
              final imgBytes = bytes;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  slideRoute(ChatFullscreenImageViewer(imageBytes: imgBytes)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(imgBytes, fit: BoxFit.cover),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom viewer opened by tapping an image bubble.
class ChatFullscreenImageViewer extends StatelessWidget {
  final Uint8List imageBytes;

  const ChatFullscreenImageViewer({super.key, required this.imageBytes});

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
          minScale: 0.5,
          maxScale: 4,
          child: Image.memory(
            imageBytes,
            errorBuilder: (context, error, stack) => Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
