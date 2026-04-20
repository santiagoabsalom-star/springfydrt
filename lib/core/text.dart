class Formatter {
//metodo auxiliar para formatear el nombre de la cancion:D
  static String format(String songName) {
    if (songName.isNotEmpty) {
      final regex = RegExp(r'\[[a-zA-Z0-9_-]{11}\]\.(mp3|wav|webm|m4a)$');

      if (songName.contains(regex)) {
        return songName.replaceAll(regex, '');
      }

      return songName.replaceAll(RegExp(r'\.(mp3|wav|webm|m4a)$'), '');
    }
    return songName;
  }

}