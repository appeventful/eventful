import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../widgets/custom_avatar.dart';
import '../utils/constants.dart';
import '../screens/profile_screen.dart';

class CommentTile extends StatelessWidget {
  final String commentId;
  final Map<String, dynamic> comment;
  final bool isMyComment;
  final bool isOrganizer;
  final Map<String, dynamic> eventData;
  final bool hasStaff;
  final bool isCreatorUser;
  final VoidCallback onLongPress;
  final Function(String, Map<String, dynamic>) onReactionTap;
  final Function(String, List) onReactionLongPress;

  const CommentTile({
    super.key,
    required this.commentId,
    required this.comment,
    required this.isMyComment,
    required this.isOrganizer,
    required this.eventData,
    required this.hasStaff,
    required this.isCreatorUser,
    required this.onLongPress,
    required this.onReactionTap,
    required this.onReactionLongPress,
  });

  @override
  Widget build(BuildContext context) {
    String? replyToId = comment['replyToId'];
    Map<String, dynamic> reactions = comment['reactions'] ?? {};
    var timestamp = comment['timestamp'];
    DateTime? date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp);
    }
    String timeStr = date != null ? DateFormat('HH:mm').format(date) : '';
    bool isPinned = eventData['pinnedCommentId'] == commentId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMyComment ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isPinned)
            const Padding(
              padding: EdgeInsets.only(left: 48, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.push_pin, size: 12, color: Colors.amber),
                  SizedBox(width: 4),
                  Text('Sabitlendi', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: isMyComment ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMyComment) ...[
                _buildAvatar(context, comment['userId']),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMyComment ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMyComment)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(comment['userId']).get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || !snapshot.data!.exists) {
                              return Text(
                                comment['userName'] ?? 'Anonim',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isOrganizer ? Colors.orange : Colors.grey[600],
                                ),
                              );
                            }
                            
                            final userData = UserModel.fromFirestore(snapshot.data!);
                            return Text(
                              userData.name,
                              style: userData.getNameStyle(
                                context,
                                fontSize: 11,
                                isBold: true,
                              ).copyWith(
                                color: (userData.supporterTier == 'none' && isOrganizer) 
                                  ? Colors.orange 
                                  : null,
                              ),
                            );
                          },
                        ),
                      ),
                    GestureDetector(
                      onLongPress: onLongPress,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMyComment ? Colors.orange : Colors.grey[100],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMyComment ? 16 : 4),
                            bottomRight: Radius.circular(isMyComment ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (replyToId != null) _buildReplyPreview(context, replyToId),
                            _buildCommentText(comment['text'] ?? ''),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (comment['isEdited'] == true)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Text('düzenlendi', style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.black26)),
                                  ),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isMyComment ? Colors.white.withValues(alpha: 0.7) : Colors.black26,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (reactions.isNotEmpty) _buildReactionsRow(reactions),
                  ],
                ),
              ),
              if (isMyComment) ...[
                const SizedBox(width: 8),
                _buildAvatar(context, comment['userId']),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String? userId) {
    if (userId == null) return const CustomAvatar(radius: 16);
    
    final String? commentUserImage = comment['userImage'];
    
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: userId))),
      child: CustomAvatar(
        radius: 16,
        imageUrl: commentUserImage,
        // passive status won't be realtime in comments for performance, but that's a fair tradeoff
        isPassive: false,
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context, String replyToId) {
    // If we already have the name stored in the current comment, we can show it immediately
    // or use it while fetching the rest of the data.
    final String? storedReplyName = comment['replyToName'];
    final String eventId = eventData['eventId'] ?? eventData['id'] ?? '';

    if (eventId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('comments')
          .doc(replyToId)
          .get(),
      builder: (context, snapshot) {
        // Even if the fetch is loading or failed, if we have the name, we show a basic placeholder
        if (!snapshot.hasData || !snapshot.data!.exists) {
          if (storedReplyName != null) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isMyComment ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: isMyComment ? Colors.white70 : Colors.orange, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storedReplyName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: isMyComment ? Colors.white : Colors.orange,
                    ),
                  ),
                  const Text('...', style: TextStyle(fontSize: 11)),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isMyComment ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: isMyComment ? Colors.white70 : Colors.orange, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['userName'] ?? '...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: isMyComment ? Colors.white : Colors.orange,
                ),
              ),
              Text(
                data['text'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isMyComment ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentText(String text) {
    List<TextSpan> spans = [];
    RegExp exp = RegExp(r'(@\w+)');
    int lastMatchEnd = 0;

    for (var match in exp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
      ));
      lastMatchEnd = match.end;
    }
    
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          color: isMyComment ? Colors.white : Colors.black87,
          fontFamily: 'Roboto',
        ),
        children: spans,
      ),
    );
  }

  Widget _buildReactionsRow(Map<String, dynamic> reactions) {
    List<Widget> chips = [];
    reactions.forEach((emoji, uids) {
      List uidList = uids as List;
      if (uidList.isNotEmpty) {
        chips.add(
          GestureDetector(
            onTap: () => onReactionTap(emoji, reactions),
            onLongPress: () => onReactionLongPress(emoji, uidList),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 2),
                  Text('${uidList.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      }
    });

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: chips,
      ),
    );
  }
}
