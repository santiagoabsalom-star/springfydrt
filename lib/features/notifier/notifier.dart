import 'dart:developer';

import 'package:flutter/cupertino.dart';

class DownloadsNotifier extends ChangeNotifier {
  DownloadsNotifier._();
  static final instance = DownloadsNotifier._();

  void notify() {
    log('notificandoputos');
    notifyListeners();
  }
}
