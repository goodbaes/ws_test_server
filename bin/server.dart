import 'dart:io';

import 'package:redis/redis.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

var _clients = <WebSocketChannel>[];
late final RedisConnection redisConnection;
late final Command command;
// Configure routes.
final _router = Router()
  ..get('/', _rootHandler)
  ..get('/echo/<message>', _echoHandler)
  ..get('/ws', webSocketHandler(_wsHendler));

void _wsHendler(WebSocketChannel webSocket) {
  _clients.add(webSocket);

  command.send_object(['GET', 'counter']).then(
    (value) => webSocket.sink.add(value.toString()),
  );

  stdout.writeln('[CONNECTED] $webSocket');

  webSocket.stream.listen((dynamic message) async {
    stdout.writeln('[RECEVED] $message');
    final newValue = await command.send_object(['INCR', 'counter']);
    if (message == 'increment') {
      for (final client in _clients) {
        client.sink.add(newValue.toString());
      }
    }
  }, onDone: () {
    _clients.remove(webSocket);
  });
}

Response _rootHandler(Request req) {
  return Response.ok('Hello, World!\n');
}

Response _echoHandler(Request request) {
  final message = request.params['message'];
  return Response.ok('$message\n');
}

void main(List<String> args) async {
  redisConnection = RedisConnection();
  command = await redisConnection.connect('localHost', 6379);
  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(_router);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}
