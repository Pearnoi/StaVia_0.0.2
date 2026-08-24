import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/plot_download_service.dart';
import '../viewmodel/all_viewmodel.dart';

class DownloadPlotsButton extends StatefulWidget {
  const DownloadPlotsButton({super.key});

  @override
  State<DownloadPlotsButton> createState() => _DownloadPlotsButtonState();
}

class _DownloadPlotsButtonState extends State<DownloadPlotsButton> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PipelineViewModel>();
    final plotData = viewModel.plotData;
    final jobId = viewModel.jobId;

    print('PlotData keys: ${plotData.keys}');
    print('PlotData isEmpty: ${plotData.isEmpty}');
    print('PlotData: $plotData');

    final hasPlots = plotData.isNotEmpty;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading || !hasPlots 
                ? null 
                : () => _downloadPlots(plotData, jobId),
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(_isLoading ? 'Downloading...' : 'Download All Plots'),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPlots ? Colors.teal : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 14),
          ),
        ],
      ],
    );
  }

  Future<void> _downloadPlots(Map<String, String> plotData, String? jobId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await PlotDownloadService.downloadAllPlots(
      plotData: plotData,
      fileName: jobId != null 
          ? 'plots_$jobId.zip' 
          : 'all_plots.zip',
      onSuccess: () {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Plots downloaded successfully!', success: true);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = error;
        });
        _showSnackBar('Download failed: $error', success: false);
      },
    );
  }

  void _showSnackBar(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}