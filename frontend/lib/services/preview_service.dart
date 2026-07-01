// lib/services/preview_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class PreviewService {
  static const String baseUrl = 'http://localhost:8000';

  static Future<PreviewResponse> getPlots({
    required String jobId,
    required List<String> em, // ['pca', 'umap', 'phate']
    required String colorUmap,
    required String colorScheme,
    required double nNeighbors,
    required int nComponents,
    required double minDist,
    required double spread,
  }) async {
    try {
      print('🔵 Getting plots with: jobId=$jobId, em=$em, color=$colorUmap');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/preview'),
      );

      // Add form fields
      request.fields['job_id'] = jobId;
      request.fields['color_umap'] = colorUmap;
      request.fields['color_scheme'] = colorScheme;
      request.fields['n_neighbors'] = nNeighbors.toString();  
      request.fields['n_components'] = nComponents.toString();
      request.fields['min_dist'] = minDist.toString();       
      request.fields['spread'] = spread.toString();     
      
      // Add em as list (send each value separately)
      request.fields['em'] = em.join(',');

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final Map<String, dynamic> data = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        print('✅ Plots received successfully');
        return PreviewResponse.fromJson(data);
      } else {
        print('❌ Failed to get plots: ${response.statusCode}');
        throw Exception(data['error'] ?? 'Failed to get plots');
      }
    } catch (e) {
      print('❌ Error getting plots: $e');
      rethrow;
    }
  }
}

class PreviewResponse {
  final Map<String, String?> plots; // pca, umap, phate

  PreviewResponse({required this.plots});

  factory PreviewResponse.fromJson(Map<String, dynamic> json) {
    return PreviewResponse(
      plots: {
        'pca': json['plots']?['pca'],
        'umap': json['plots']?['umap'],
        'phate': json['plots']?['phate'],
      },
    );
  }
}