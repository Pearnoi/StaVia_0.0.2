import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../services/job_service.dart';
import '../parameters/params.dart';

enum PipelineStatus {
  idle,
  uploading,
  uploadSuccess,
  preprocessing,
  preprocessSuccess,
  previewing,
  previewSuccess,
  analyzing,
  analysisSuccess,
  error,
}

class PipelineViewModel extends ChangeNotifier {
  String? _jobId;
  PipelineStatus _status = PipelineStatus.idle;
  String? _errorMessage;
 
  Map<String, dynamic>? _uploadResult;
  Map<String, dynamic>? _preprocessingResult;
  PreviewResponse? _previewResult;
  Map<String, dynamic>? _lastAnalysisResult;

  final Map<String, String> _plotData = {};

  String? get jobId => _jobId;
  PipelineStatus get status => _status;
  
  bool get isLoading => _status == PipelineStatus.uploading || 
                        _status == PipelineStatus.preprocessing || 
                        _status == PipelineStatus.previewing || 
                        _status == PipelineStatus.analyzing;
                        
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get uploadResult => _uploadResult;
  Map<String, dynamic>? get lastAnalysisResult => _lastAnalysisResult;
  Map<String, dynamic>? get preprocessingResult => _preprocessingResult;
  PreviewResponse? get previewResult => _previewResult; 
  Map<String, String> get plotData => Map.unmodifiable(_plotData);

  Future<void> handleFileUpload(PlatformFile file) async {
    _setLoading(PipelineStatus.uploading);
    _errorMessage = null;
    
    try {
      final res = await uploadFile(file);
      if (res != null) {
        _uploadResult = res;
        _preprocessingResult = null;
        _plotData.clear();         

        _jobId = res['job_id']?.toString() ?? res['data']?['job_id']?.toString();
        
        _status = PipelineStatus.uploadSuccess;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      notifyListeners();
    }
  }

  Future<void> handlePreprocessing(PreprocessParams params) async {
    _setLoading(PipelineStatus.preprocessing);
    try {
      _preprocessingResult = await runPreprocessing(params);
      _status = PipelineStatus.preprocessSuccess;
    } catch (e) {
      _setError(e.toString());
    } finally {
      notifyListeners();
    }
  }
  
  Future<void> handlePreview(PreviewParams params) async {
    _setLoading(PipelineStatus.previewing);
    try {
      _previewResult = await getPlots(params);
      _status = PipelineStatus.previewSuccess;
    } catch (e) {
      _setError(e.toString());
    } finally {
      notifyListeners();
    }
  }

  Future<void> handleAnalysis(AnalyzeParams params) async {
    _setLoading(PipelineStatus.analyzing);
    try {
      _lastAnalysisResult = await runAnalysis(params);
      _plotData.clear();

      final rawPlots = _lastAnalysisResult?['plots'];
      if (rawPlots is Map) {
        rawPlots.forEach((key, value) {
          if (value is String && value.isNotEmpty) {
            _plotData[key.toString()] = value;
          }
        });
      }
      
      _status = PipelineStatus.analysisSuccess;
    } catch (e) {
      _setError(e.toString());
    } finally {
      notifyListeners();
    }
  }

  void _setLoading(PipelineStatus status) {
    _status = status;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = PipelineStatus.error;
    notifyListeners();
  }
}