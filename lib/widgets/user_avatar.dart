import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final double radius;
  // When true, avatar background follows theme primary color.
  final bool useThemePrimary;

  const UserAvatar({
    Key? key,
    this.imageUrl,
    required this.displayName,
    this.radius = 20,
    this.useThemePrimary = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
        onBackgroundImageError: (_, __) {
          // If image fails to load, show initials
        },
        child: null,
      );
    }

    // Show initials if no image URL or image fails to load
    final initials = _getInitials(displayName);
    
    final theme = Theme.of(context);
    final bg = useThemePrimary ? theme.colorScheme.primary : _getColorFromName(displayName);
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return '?';
    
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    } else {
      return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
    }
  }

  Color _getColorFromName(String name) {
    // Palette intentionally avoids yellow/amber tones to prevent
    // giving the UI an overall 'yellow' tint. Uses a neutral/cool set.
    final colors = [
      Colors.red.shade400,
      Colors.pink.shade400,
      Colors.purple.shade400,
      Colors.deepPurple.shade400,
      Colors.indigo.shade400,
      Colors.blue.shade400,
      Colors.lightBlue.shade400,
      Colors.cyan.shade400,
      Colors.teal.shade400,
      Colors.green.shade400,
      Colors.lightGreen.shade400,
      Colors.deepOrange.shade400,
      Colors.brown.shade400,
      Colors.blueGrey.shade400,
      Colors.grey.shade600,
      Colors.black87,
    ];

    final hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }
}
