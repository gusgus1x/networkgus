import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final double radius;

  const UserAvatar({
    Key? key,
    this.imageUrl,
    required this.displayName,
    this.radius = 20,
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
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: _getColorFromName(displayName),
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
      Colors.lime.shade400,
      Colors.yellow.shade400,
      Colors.amber.shade400,
      Colors.orange.shade400,
      Colors.deepOrange.shade400,
    ];
    
    final hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }
}