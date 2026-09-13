import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

class StartupPoster extends StatelessWidget {
  const StartupPoster({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF7),
      body: SizedBox.expand(
        child: Image.asset(
          AppAssets.startupPoster,
          // The source poster is 9:16 while modern phones are usually taller.
          // Cover keeps the artwork edge-to-edge without stretching the logo
          // or typography; the crop is limited to the poster's side margins.
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
