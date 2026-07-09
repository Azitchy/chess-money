import 'package:flutter/material.dart';

class LoginBackdrop extends StatelessWidget {
  const LoginBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEAF5FF), Color(0xFFF8FBFF)],
            ),
          ),
        ),
        const Positioned(
          top: -68,
          left: -56,
          child: _CircleBlob(size: 220, color: Color(0xFF61B6FF)),
        ),
        const Positioned(
          top: -88,
          right: -84,
          child: _CircleBlob(size: 270, color: Color(0xFF7B74F7)),
        ),
        Positioned(
          left: -28,
          right: -28,
          bottom: -26,
          child: Container(
            height: 92,
            decoration: BoxDecoration(
              color: const Color(0xFF49A6F4),
              borderRadius: BorderRadius.circular(34),
            ),
          ),
        ),
      ],
    );
  }
}

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        color: Color(0xFF44A7F5),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 68, color: Colors.white),
    );
  }
}

class _CircleBlob extends StatelessWidget {
  const _CircleBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
