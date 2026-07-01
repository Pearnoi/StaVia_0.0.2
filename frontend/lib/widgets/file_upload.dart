import 'package:flutter/material.dart';
import 'package:stavia_ff/services/upload_service.dart';

class FilePickerTest extends StatefulWidget {
  final VoidCallback? onUploadStart;
  final Function(Map<String, dynamic>)? onUploadComplete;
  final Function(String)? onUploadError;
  
  const FilePickerTest({
    super.key,
    this.onUploadStart,
    this.onUploadComplete,
    this.onUploadError,
  });

  @override
  State<FilePickerTest> createState() => _FilePickerTestState();
}

class _FilePickerTestState extends State<FilePickerTest> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _pickAndUploadFile,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.upload_file),
          label: Text(_isLoading ? 'Uploading...' : 'Pick and Upload File'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.black38,
              foregroundColor: Colors.white,
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickAndUploadFile() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  widget.onUploadStart?.call();

  try {
    final file = await UploadService.pickFile();
    
    if (file != null) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⬆️ Uploading ${file.name}...'),
          duration: const Duration(seconds: 2),
        ),
      );
      
      final result = await UploadService.uploadFile(file);
      
      if (result != null) {
        setState(() {
          _isLoading = false;
        });
        widget.onUploadComplete?.call(result);
        
        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result['message'] ?? 'Upload successful!'}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      
      // Show no file selected snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No file selected'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    setState(() {
      _errorMessage = e.toString();
      _isLoading = false;
    });
    widget.onUploadError?.call(e.toString());
    
    // Show error snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Error: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
}