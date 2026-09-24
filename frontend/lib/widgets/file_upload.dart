import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/all_viewmodel.dart';
import '../services/job_service.dart';

class FilePickerTest extends StatelessWidget {
  const FilePickerTest({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PipelineViewModel>();
    final isLoading = viewModel.isLoading;
    final errorMessage = viewModel.errorMessage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: isLoading ? null : () => _handlePickAndUpload(context),
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.upload_file),
          label: Text(isLoading ? 'Uploading...' : 'Pick and Upload File'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: Colors.black38,
            foregroundColor: Colors.white,
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                errorMessage,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handlePickAndUpload(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = context.read<PipelineViewModel>();
    final file = await pickFile();

    if (file == null) return;

    await viewModel.handleFileUpload(file);

    if (!context.mounted) return;

    if (viewModel.status == PipelineStatus.uploadSuccess) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Upload successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (viewModel.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${viewModel.errorMessage}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}