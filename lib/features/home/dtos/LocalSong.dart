class LocalSong {
  late final String title;
  late  String path;
  late final String? videoId;

  LocalSong({
    required this.title,
    required this.path,
    required this.videoId,
  });
  void setVideoId(String videoId) {
    this.videoId = videoId;}
  void setPath(String path) {
    this.path = path;
  }
  void setTitle(String title) {
    this.title = title;
  }


}
