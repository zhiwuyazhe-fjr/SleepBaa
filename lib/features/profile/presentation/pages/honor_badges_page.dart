import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_badges_page.dart';

class HonorBadgesPage extends StatelessWidget {
  const HonorBadgesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileBadgesPage(mode: BadgeCatalogMode.dorm);
  }
}
