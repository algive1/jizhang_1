import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.radius = 24});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE7DECE),
      backgroundImage: const AssetImage(AppAssets.userAvatar),
    );
  }
}
