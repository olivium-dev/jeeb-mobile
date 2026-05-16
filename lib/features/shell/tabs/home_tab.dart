import 'package:flutter/material.dart';

import '../../home_client/presentation/client_home_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClientHomeScreen(key: Key('home-tab-root'));
  }
}
