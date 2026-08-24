import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../parameters/params.dart';

const String baseUrl = 'http://localhost:8000';
String? _jobId; 

// Upload Endpoint 
Future<PlatformFile?> pickFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    type: FileType.custom,
    allowedExtensions: ['zip', 'h5ad', 'csv', 'tsv', 'mtx'],
    withData: true,
  );
  
  if (result != null) {
    return result.files.first;
  }
  return null;
}

Future<Map<String, dynamic>?> uploadFile(PlatformFile file) async {
  try {
    final fileBytes = file.bytes;
    if (fileBytes == null) {
      throw Exception('File bytes are null');
    }

    final uri = Uri.parse('$baseUrl/upload');
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
      _jobId = data["job_id"];
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
    print('Upload error: $e');
    rethrow;
  }
}

// Rename job endpoint
Future<void> renameJob(String jobId, String newName) async { 
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/rename/$jobId') 
    );
  
    if (response.statusCode != 200) {
      throw Exception('Failed to load session: ${response.body}');
    }
  } catch (e) {
    throw Exception('Network error: $e');
  }
}

// Delete job endpoint 
Future<void> deleteJob(String jobId) async {
  try {
    final response = await http.delete(
      Uri.parse('$baseUrl/job/$jobId') 
    );
  
    if (response.statusCode != 200) {
      throw Exception('Failed to load session: ${response.body}');
    }
  } catch (e) {
    throw Exception('Network error: $e');
  }
}

// Preprocess endpoint 

Future<Map<String, dynamic>> runPreprocessing(PreprocessParams params) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/preprocess/${params.jobId}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(params.toJson()),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        print('Error: $data');
        throw Exception(data['detail'] ?? data['error'] ?? 'Preprocessing failed');
      }
    } catch (e) {
      rethrow;
    }
}

// TODO PARC Endpoint

// Preview Endpoint
Future<PreviewResponse> getPlots(PreviewParams params) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/preview/${params.jobId}'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(params.toJson()),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return PreviewResponse.fromJson(data);
    } else {
      throw Exception(data['detail'] ?? data['error'] ?? 'Failed to get plots');
    }
  } catch (e) {
    rethrow;
  }
}

// Analyze Endpoint
Future<Map<String, dynamic>> runAnalysis(AnalyzeParams params) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze/${params.jobId}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(params.toJson()),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['detail'] ?? data['error'] ?? 'VIA analysis failed');
        }
      } else {
        throw Exception(data['detail'] ?? data['error'] ?? 'VIA analysis failed');
      }
    } catch (e) {
      rethrow;
    }
}

// Download Plots Endpoint 