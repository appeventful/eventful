import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';

class CustomAvatar extends StatelessWidget {
  final UserModel? user;
  final String? imageUrl; // Manuel URL desteği için (topluluk ikonları vb.)
  final double radius;
  final IconData placeholderIcon;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool isPassive;
  final List<String>? badgeIcons;
  final bool isMe;
  final bool isAdminView;

  const CustomAvatar({
    super.key,
    this.user,
    this.imageUrl,
    this.radius = 20,
    this.placeholderIcon = Icons.person,
    this.backgroundColor,
    this.iconColor,
    this.isPassive = false,
    this.badgeIcons,
    this.isMe = false,
    this.isAdminView = false,
  });

  @override
  Widget build(BuildContext context) {
    String finalUrl = '';
    
    if (user != null) {
      finalUrl = user!.getEffectiveImageUrl(isMe: isMe, viewerIsAdmin: isAdminView);
    } else if (imageUrl != null) {
      finalUrl = imageUrl!;
    }

    Widget avatar;

    if (finalUrl.isNotEmpty && finalUrl != "null") {
      if (finalUrl.startsWith('http')) {
        avatar = CachedNetworkImage(
          imageUrl: finalUrl,
          memCacheHeight: (radius * 3).toInt(), // RAM tasarrufu için ölçekli yükleme
          memCacheWidth: (radius * 3).toInt(),
          imageBuilder: (context, imageProvider) => CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor ?? Colors.grey[200],
            backgroundImage: imageProvider,
          ),
          placeholder: (context, url) => CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor ?? Colors.grey[200],
            child: SizedBox(
              width: radius,
              height: radius,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange.withValues(alpha: 0.5),
              ),
            ),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor ?? Colors.grey[200],
            child: Icon(placeholderIcon, size: radius, color: iconColor ?? Colors.grey[400]),
          ),
        );
      } else {
        avatar = CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.grey[200],
          backgroundImage: FileImage(File(finalUrl)),
        );
      }
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey[200],
        child: Icon(placeholderIcon, size: radius, color: iconColor ?? Colors.grey[400]),
      );
    }

    if (isPassive) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.white.withValues(alpha: 0.5),
          BlendMode.dstIn,
        ),
        child: avatar,
      );
    }
    return avatar;
  }
}
