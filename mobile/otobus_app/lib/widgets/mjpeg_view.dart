import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MjpegView extends StatefulWidget {
  final String streamUrl;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const MjpegView({
    super.key,
    required this.streamUrl,
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  // Görüntü verisi
  ValueNotifier<Uint8List?> imageBytes = ValueNotifier(null);
  // Hata durumu
  ValueNotifier<bool> hasError = ValueNotifier(false);
  
  // Akışı kontrol etmek için
  StreamSubscription? _subscription;
  http.Client? _client;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _client?.close();
    super.dispose();
  }

  Future<void> _startStream() async {
    try {
      _client = http.Client();
      final request = http.Request("GET", Uri.parse(widget.streamUrl));
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        hasError.value = true;
        return;
      }

      // MJPEG akışını işleyen mantık
      List<int> buffer = [];
      _subscription = response.stream.listen((chunk) {
        buffer.addAll(chunk);
        
        // JPG Başlangıç (0xFF, 0xD8) ve Bitiş (0xFF, 0xD9) baytlarını ara
        // Basit bir MJPEG parser mantığı:
        int start = -1;
        int end = -1;

        // Performans için sadece buffer yeterince büyükse ara
        if (buffer.length > 100) {
           for (int i = 0; i < buffer.length - 1; i++) {
             if (buffer[i] == 0xFF && buffer[i+1] == 0xD8) {
               start = i;
             }
             if (buffer[i] == 0xFF && buffer[i+1] == 0xD9) {
               end = i + 2;
               if (start != -1 && end > start) {
                 // Görüntüyü bulduk!
                 final jpgBytes = Uint8List.fromList(buffer.sublist(start, end));
                 imageBytes.value = jpgBytes; // Ekrana bas
                 
                 // Buffer'ı temizle (bulunan kareden sonrasını tut)
                 buffer = buffer.sublist(end);
                 start = -1;
                 i = -1; // Aramayı sıfırla
               }
             }
           }
        }
      }, onError: (err) {
        hasError.value = true;
      });

    } catch (e) {
      hasError.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: hasError,
      builder: (context, isError, _) {
        if (isError) {
          return widget.errorWidget ?? 
            const Center(child: Icon(Icons.error, color: Colors.red));
        }

        return ValueListenableBuilder<Uint8List?>(
          valueListenable: imageBytes,
          builder: (context, bytes, _) {
            if (bytes == null) {
              return widget.loadingWidget ?? 
                const Center(child: CircularProgressIndicator());
            }
            // Memory'den resmi çiz (GaplessPlayback titremeyi önler)
            return Image.memory(
              bytes, 
              gaplessPlayback: true, 
              fit: BoxFit.contain,
            );
          },
        );
      },
    );
  }
}