import 'package:flutter/foundation.dart';

class NavigationController extends ValueNotifier<int> {
  NavigationController() : super(0);

  int get currentIndex => value;

  void changeTab(int index) {
    value = index;
  }
}
