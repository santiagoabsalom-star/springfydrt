import 'package:flutter/cupertino.dart';


import '../../core/log.dart';

class DownloadsNotifier extends ChangeNotifier {
  DownloadsNotifier._();
  static final instance = DownloadsNotifier._();

  void notify() {
    Log.d('Notificando descarga local');
    notifyListeners();
  }
}


class CloudNotifier extends ChangeNotifier {
  CloudNotifier._();

  static final instance = CloudNotifier._();

  void notify() {
    Log.d('Notificando actualización en la nube');
    notifyListeners();
  }
}
class StreamFromPlayerNotifier extends ChangeNotifier {
  StreamFromPlayerNotifier._();

  static final instance = StreamFromPlayerNotifier._();

  void notify() {
    Log.d('Notificando cambio en el stream');
    notifyListeners();
  }
}
  class StreamFromSessionNotifier extends ChangeNotifier {
StreamFromSessionNotifier._();
static final instance = StreamFromSessionNotifier._();

void notify() {
  Log.d('Notificando cambio en el stream');
  notifyListeners();
}
}
class PlayerNotifier extends ChangeNotifier {
  PlayerNotifier._();

  static final instance = PlayerNotifier._();

  void notify() {
    Log.d('Notificando cambio en el reproductor');
    notifyListeners();
  }

}
  class StreamFolderNotifier extends ChangeNotifier {
  StreamFolderNotifier._();
  static final instance = StreamFolderNotifier._();

  void notify() {
  Log.d('Notificando cambio en el folder stream');
  notifyListeners();
  }
}
