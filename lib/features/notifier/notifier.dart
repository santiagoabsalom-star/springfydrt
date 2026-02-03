import 'dart:developer';
import 'package:flutter/cupertino.dart';

class DownloadsNotifier extends ChangeNotifier {
  DownloadsNotifier._();
  static final instance = DownloadsNotifier._();

  void notify() {
    log('Notificando descarga local');
    notifyListeners();
  }
}

class CloudNotifier extends ChangeNotifier {
  CloudNotifier._();
  static final instance = CloudNotifier._();

  void notify() {
    log('Notificando actualización en la nube');
    notifyListeners();
  }
}
