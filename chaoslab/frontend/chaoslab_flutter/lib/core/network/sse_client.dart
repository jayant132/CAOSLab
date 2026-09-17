import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'dio_client.dart';

/// One parsed Server-Sent Event: `event: <name>` + `data: <payload>`.
class SseEvent {
  SseEvent({required this.event, required this.data});

  final String event;
  final String data;
}

/// Consumes the backend's `text/event-stream` endpoints
/// (`/api/v1/simulation/stream/{id}`) using Dio's raw byte stream, since
/// `dart:io`'s EventSource equivalent isn't available cross-platform
/// (notably web) the way it is in a browser natively.
///
/// This intentionally hand-rolls the (small) SSE framing spec rather than
/// pulling in a dedicated package — the parsing is ~30 lines and keeping it
/// in-house means one fewer third-party dependency for something this
/// simple.
class SseClient {
  SseClient(this._dio);

  final Dio _dio;

  Stream<SseEvent> connect(String path) {
    final controller = StreamController<SseEvent>();
    _run(path, controller);
    return controller.stream;
  }

  Future<void> _run(String path, StreamController<SseEvent> controller) async {
    try {
      final response = await _dio.get<ResponseBody>(
        path,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final stream = response.data!.stream;
      String buffer = '';

      await for (final chunk in stream) {
        // The server emits CRLF line endings (`\r\n`); normalize to `\n`
        // before buffering so frame-boundary detection below (`\n\n`)
        // actually matches. Without this, `\r\n\r\n` never matches a
        // bare `\n\n` search and the stream appears to hang forever.
        buffer += utf8.decode(chunk, allowMalformed: true).replaceAll('\r\n', '\n');

        // SSE frames are separated by a blank line.
        while (buffer.contains('\n\n')) {
          final frameEndIndex = buffer.indexOf('\n\n');
          final rawFrame = buffer.substring(0, frameEndIndex);
          buffer = buffer.substring(frameEndIndex + 2);
          _emitFrame(rawFrame, controller);
        }
      }

      await controller.close();
    } catch (error) {
      if (!controller.isClosed) {
        controller.addError(DioClient.instance.toApiException(error));
        await controller.close();
      }
    }
  }

  void _emitFrame(String rawFrame, StreamController<SseEvent> controller) {
    String eventName = 'message';
    final dataLines = <String>[];

    for (final line in rawFrame.split('\n')) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }

    if (dataLines.isNotEmpty && !controller.isClosed) {
      controller.add(SseEvent(event: eventName, data: dataLines.join('\n')));
    }
  }
}
