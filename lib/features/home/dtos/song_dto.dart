class SongDto {
  final List<VideoInfo> videosInfo;

  SongDto({
    required this.videosInfo,
  });

  factory SongDto.fromJson(Map<String, dynamic> json) {
    return SongDto(
      videosInfo: (json['videosInfo'] as List)
          .map((e) => VideoInfo.fromJson(e))
          .toList(),
    );
  }
}

class VideoInfo {
  final String videoId;
  final String title;
  final String channelTitle;

  VideoInfo({
    required this.videoId,
    required this.title,
    required this.channelTitle,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      videoId: json['videoId'],
      title: json['title'],
      channelTitle: json['channelTitle'],
    );
  }
}
