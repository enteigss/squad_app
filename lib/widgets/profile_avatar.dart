import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.onTap,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor ?? theme.primaryColor,
            backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl!) as ImageProvider
                : null,
            child: imageUrl == null || imageUrl!.isEmpty
                ? Text(
                    _getInitials(name),
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: radius * 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          if (showOnlineIndicator)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: radius * 0.4,
                height: radius * 0.4,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    
    final List<String> words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    } else {
      return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
    }
  }
}

class ProfileAvatarWithBadge extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final int badgeCount;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final Color badgeColor;

  const ProfileAvatarWithBadge({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.badgeCount = 0,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.badgeColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ProfileAvatar(
          imageUrl: imageUrl,
          name: name,
          radius: radius,
          onTap: onTap,
          backgroundColor: backgroundColor,
          textColor: textColor,
        ),
        if (badgeCount > 0)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              constraints: BoxConstraints(
                minWidth: radius * 0.5,
                minHeight: radius * 0.5,
              ),
              child: Text(
                badgeCount > 99 ? '99+' : badgeCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.25,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}