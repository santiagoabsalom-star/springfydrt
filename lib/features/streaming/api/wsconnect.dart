import 'package:web_socket_channel/io.dart';
final Uri streamUri= Uri.parse("ws://springfy.tplinkdns.com:3051/stream");

Map<String, String> applicationHeader= {
  'Application-id': 'sp-rin-g-fy-id-application-android/29912/'

};

Future<IOWebSocketChannel> connect(Map<String,String> headers) async {
  headers.addAll(applicationHeader);
final channel = IOWebSocketChannel.connect(streamUri, headers: headers);

return channel;

}





