import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';


























class RootAwareBackScope extends StatelessWidget {
  const RootAwareBackScope({
    super.key,
    required this.fallbackLocation,
    required this.child,
  });

  
  
  
  
  
  final String fallbackLocation;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackLocation);
        }
        
        
        return true;
      },
      child: child,
    );
  }
}
