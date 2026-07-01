import 'dart:convert';
import 'dart:io' show Platform, File, Directory;  // ← Only import what you need
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class PlotDownloadService {
  static const String baseUrl = 'http://localhost:8000';

  static Future<void> downloadAllPlots({
    required Map<String, String> plotData,
    String? fileName,
    VoidCallback? onSuccess,
    void Function(String)? onError,
  }) async {
    try {
      if (!kIsWeb) {
        // Request storage permission (Android only)
        if (Platform.isAndroid) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            onError?.call('Storage permission denied');
            return;
          }
        }
      }

      // Download the zip file
      final response = await http.post(
        Uri.parse('$baseUrl/download_all'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'plot_data': plotData}),
      );

      if (response.statusCode != 200) {
        String errorMessage;
        try {
          final error = jsonDecode(response.body);
          errorMessage = error['detail'] ?? 'Failed to download plots';
        } catch (e) {
          errorMessage = 'Failed to download plots: ${response.statusCode}';
        }
        onError?.call(errorMessage);
        return;
      }

      // Save the file
      final String fileNameToUse = fileName ?? 'all_plots.zip';
      final String filePath = await _saveFile(response.bodyBytes, fileNameToUse);

      if (kDebugMode) {
        print('Download complete: $filePath');
      }

      onSuccess?.call();

    } catch (e) {
      if (kDebugMode) {
        print('Download error: $e');
      }
      onError?.call('Error downloading plots: $e');
    }
  }

  static Future<String> _saveFile(List<int> bytes, String fileName) async {
    try {
      Directory? downloadDir;

      // ✅ WEB: Use browser download instead of file system
      if (kIsWeb) {
        // For web, use html anchor tag to trigger download
        _downloadOnWeb(bytes, fileName);
        return 'Download initiated in browser';
      }

      // Desktop/Mobile: Use file system
      if (Platform.isAndroid) {
        // Android: Downloads folder
        final baseDir = await getExternalStorageDirectory();
        final downloadsDir = Directory('${baseDir?.path}/Downloads');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        downloadDir = downloadsDir;
      } else if (Platform.isIOS) {
        // iOS: Documents directory
        downloadDir = await getApplicationDocumentsDirectory();
      } else {
        // Desktop: Temporary directory
        downloadDir = await getTemporaryDirectory();
      }

      final String filePath = '${downloadDir.path}/$fileName';
      await File(filePath).writeAsBytes(bytes);
      return filePath;

    } catch (e) {
      // Fallback to temporary directory
      final tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$fileName';
      await File(filePath).writeAsBytes(bytes);
      return filePath;
    }
  }

  // ✅ WEB: Browser download using html package
  static void _downloadOnWeb(List<int> bytes, String fileName) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..target = 'blank'
      ..download = fileName;
    anchor.click();
    html.Url.revokeObjectUrl(url);
  }
}