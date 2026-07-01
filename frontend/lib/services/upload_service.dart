import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UploadService {
  static Future<PlatformFile?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['zip', 'h5ad', 'csv', 'tsv', 'mtx'],
    );
    
    if (result != null) {
      return result.files.first;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> uploadFile(PlatformFile file) async {
    try {
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        throw Exception('File bytes are null');
      }

      final uri = Uri.parse('http://localhost:8000/upload');
      final request = http.MultipartRequest('POST', uri);
      
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: file.name,
      );
      
      request.files.add(multipartFile);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          throw Exception(errorData['error'] ?? 'Upload failed with status: ${response.statusCode}');
        } catch (e) {
          throw Exception('Upload failed with status: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
  }
}