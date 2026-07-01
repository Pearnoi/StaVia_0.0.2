import 'dart:convert';
import 'package:http/http.dart' as http;

class AnalyzeService {
  static const String baseUrl = 'http://localhost:8000';

  static Future<Map<String, dynamic>> runAnalysis({
    required String jobId,
    String? varNames,
    required int knn,
    required double clusterGraphPruning,
    required double edgebundlePruning,
    required double edgepruningClusteringResolution,
    required int dpi,
    String? obs,
    required List<String> parOption,
  }) async {
    try {
      print('🔵 Running VIA analysis for job: $jobId');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/analyze'),
      );

      // Add form fields
      request.fields['job_id'] = jobId;
      request.fields['knn'] = knn.toString();
      request.fields['cluster_graph_pruning'] = clusterGraphPruning.toString();
      request.fields['edgebundle_pruning'] = edgebundlePruning.toString();
      request.fields['edgepruning_clustering_resolution'] = edgepruningClusteringResolution.toString();
      request.fields['dpi'] = dpi.toString();
      
      // Optional fields
      if (varNames != null && varNames.isNotEmpty) {
        request.fields['var_names'] = varNames;
      }
      if (obs != null && obs.isNotEmpty) {
        request.fields['obs'] = obs;
      }
      
      // Send par-option as multiple fields
      for (var option in parOption) {
        request.fields['par-option'] = option;
      }

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final Map<String, dynamic> data = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          print('✅ VIA analysis complete');
          return data;
        } else {
          throw Exception(data['error'] ?? 'VIA analysis failed');
        }
      } else {
        throw Exception(data['error'] ?? 'VIA analysis failed');
      }
    } catch (e) {
      print('❌ VIA analysis error: $e');
      rethrow;
    }
  }
}