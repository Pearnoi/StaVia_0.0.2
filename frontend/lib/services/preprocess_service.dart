import 'dart:convert';
import 'package:http/http.dart' as http;

class PreprocessService {
  static const String baseUrl = 'http://localhost:8000';

  static Future<PreprocessResult> runPreprocessing({
    required String jobId,
    required String choice, 
    required String order,  
  }) async {
    try {
      print('🔵 Running preprocessing with choice: $choice, order: $order');

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/preprocess'),
      );

      // Add form data
      request.fields['job_id'] = jobId;
      request.fields['preprocessing_choice'] = choice;
      request.fields['preprocessing_order'] = order;

      // Send request
      var response = await request.send();

      // Get response
      final responseBody = await response.stream.bytesToString();
      final Map<String, dynamic> data = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        print('✅ Preprocessing successful!');
        return PreprocessResult.fromJson(data);
      } else {
        print('❌ Preprocessing failed: ${response.statusCode}');
        print('Error: $data');
        throw Exception(data['error'] ?? 'Preprocessing failed');
      }
    } catch (e) {
      print('❌ Preprocessing error: $e');
      rethrow;
    }
  }
}

class PreprocessResult {
  final String dimensions;
  final List<String> obsKeys;
  final List<String> varKeys;
  final List<String> layers;
  final List<String> unsKeys;
  final List<String> obsmKeys;
  final List<String> varmKeys;

  PreprocessResult({
    required this.dimensions,
    required this.obsKeys,
    required this.varKeys,
    required this.layers,
    required this.unsKeys,
    required this.obsmKeys,
    required this.varmKeys,
  });

  factory PreprocessResult.fromJson(Map<String, dynamic> json) {
    final adataInfo = json['adata_info'] ?? {};
    return PreprocessResult(
      dimensions: adataInfo['dimensions'] ?? 'Unknown',
      obsKeys: List<String>.from(adataInfo['obs_keys'] ?? []),
      varKeys: List<String>.from(adataInfo['var_keys'] ?? []),
      layers: List<String>.from(adataInfo['layers'] ?? []),
      unsKeys: List<String>.from(adataInfo['uns_keys'] ?? []),
      obsmKeys: List<String>.from(adataInfo['obsm_keys'] ?? []),
      varmKeys: List<String>.from(adataInfo['varm_keys'] ?? []),
    );
  }
}