import 'package:flutter/material.dart';
import '../services/plot_download_service.dart';

class DownloadPlotsButton extends StatefulWidget {
  final Map<String, String> plotData;
  final String? jobId;

  const DownloadPlotsButton({
    super.key,
    required this.plotData,
    this.jobId,
  });

  @override
  State<DownloadPlotsButton> createState() => _DownloadPlotsButtonState();
}

class _DownloadPlotsButtonState extends State<DownloadPlotsButton> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    print('PlotData keys: ${widget.plotData.keys}');
    print('PlotData isEmpty: ${widget.plotData.isEmpty}');
    print('PlotData: ${widget.plotData}');

    final hasPlots = widget.plotData.isNotEmpty;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading || !hasPlots ? null : _downloadPlots,
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

  Future<void> _downloadPlots() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await PlotDownloadService.downloadAllPlots(
      plotData: widget.plotData,
      fileName: widget.jobId != null 
          ? 'plots_${widget.jobId}.zip' 
          : 'all_plots.zip',
      onSuccess: () {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Plots downloaded successfully!', success: true);
      },
      onError: (error) {
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