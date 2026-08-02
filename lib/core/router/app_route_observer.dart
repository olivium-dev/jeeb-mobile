import 'package:flutter/widgets.dart';

















RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();












RouteObserver<ModalRoute<void>> newAppRouteObserver() =>
    appRouteObserver = RouteObserver<ModalRoute<void>>();
