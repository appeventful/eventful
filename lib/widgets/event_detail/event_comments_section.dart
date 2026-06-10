import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/comment_tile.dart';

class EventCommentsSection extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> eventData;
  final bool hasStaff;
  final bool isCreatorUser;
  final AsyncSnapshot<QuerySnapshot> snapshot;
  final Function(String commentId, Map<String, dynamic> comment, bool canDeleteAny, bool isMine, Map<String, dynamic> eventData, bool hasStaff) onShowCommentOptions;
  final Function(String commentId, String emoji, Map<String, dynamic> allReactions) onToggleReaction;
  final Function(String emoji, List uids) onShowReactionDetails;

  const EventCommentsSection({
    super.key,
    required this.eventId,
    required this.eventData,
    required this.hasStaff,
    required this.isCreatorUser,
    required this.snapshot,
    required this.onShowCommentOptions,
    required this.onToggleReaction,
    required this.onShowReactionDetails,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (snapshot.hasError) {
      return const SliverToBoxAdapter(
        child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Sohbet yüklenirken hata oluştu.')))
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
      return const SliverToBoxAdapter(
        child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
      );
    }

    var comments = snapshot.data?.docs ?? [];
    if (comments.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Henüz yorum yok. İlk yorumu sen yap!')))
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            var commentDoc = comments[index];
            var comment = commentDoc.data() as Map<String, dynamic>;
            String commentUserId = comment['userId'] ?? '';
            bool isMyComment = commentUserId == currentUser?.uid;
            bool isOrganizer = commentUserId == eventData['creatorId'];

            final Map<String, dynamic> enrichedEventData = Map.from(eventData);
            enrichedEventData['eventId'] = eventId;

            return RepaintBoundary(
              child: CommentTile(
                key: ValueKey(commentDoc.id),
                commentId: commentDoc.id,
                comment: comment,
                isMyComment: isMyComment,
                isOrganizer: isOrganizer,
                eventData: enrichedEventData,
                hasStaff: hasStaff,
                isCreatorUser: isCreatorUser,
                onLongPress: () => onShowCommentOptions(commentDoc.id, comment, isCreatorUser || hasStaff, isMyComment, eventData, hasStaff),
                onReactionTap: (emoji, reactions) => onToggleReaction(commentDoc.id, emoji, reactions),
                onReactionLongPress: (emoji, uids) => onShowReactionDetails(emoji, uids),
              ),
            );
          },
          childCount: comments.length,
        ),
      ),
    );
  }
}
