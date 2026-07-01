import 'dart:convert';
import 'package:http/http.dart' as http;

class ParcService {
  static const String baseUrl = 'http://localhost:8000';

  static Future<String?> runParc({
    required String jobId,
    int nNeighbors = 10,
    int nPcs = 40,
    double jacStdGlobal = 0.15,
    int randomSeed = 1,
    int smallPop = 50,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/run_parc'),
      );

      request.fields['job_id'] = jobId;
      request.fields['n_neighbors'] = nNeighbors.toString();
      request.fields['n_pcs'] = nPcs.toString();
      request.fields['jac_std_global'] = jacStdGlobal.toString();
      request.fields['random_seed'] = randomSeed.toString();
      request.fields['small_pop'] = smallPop.toString();

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final Map<String, dynamic> data = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        return data['plots']?['parc'];
      } else {
        throw Exception(data['error'] ?? 'PARC analysis failed');
      }
    } catch (e) {
      print('❌ PARC error: $e');
      rethrow;
    }
  }
}