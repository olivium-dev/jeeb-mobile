import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'app/jeeb_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Force the semantics tree ON for the app's entire lifetime. Flutter only
  // publishes its accessibility/semantics tree when a client requests it (an
  // a11y service is active, or someone holds a SemanticsHandle). Maestro reads
  // the platform accessibility tree, so without this the tree is empty and
  // `maestro hierarchy` returns nodes with no text/identifier — making every
  // id-based assertion impossible. Holding this handle (never disposing it)
  // keeps semantics published so Maestro can see Semantics(identifier:) values.
  // Flutter 3.44.2: SemanticsBinding.instance.ensureSemantics() returns a
  // SemanticsHandle; we intentionally retain it for the process lifetime.
  SemanticsBinding.instance.ensureSemantics();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const JeebBootstrap());
}
