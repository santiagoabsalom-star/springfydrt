class DownloadRequest {
  final String videoId;

  const DownloadRequest({
    required this.videoId,
  });

  factory DownloadRequest.fromJson(Map<String, dynamic> json) {
    return DownloadRequest(
      videoId: json['videoId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
    };
  }
}
