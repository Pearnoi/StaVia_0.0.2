import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../parameters/params.dart'; 
import '../viewmodel/all_viewmodel.dart';
import '../widgets/plot_carousel.dart';

class PreviewData extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic>? adataInfo;
  final Function(Map<String, String>)? onPlotsGenerated;

  const PreviewData({
    super.key,
    required this.jobId,
    this.adataInfo,
    this.onPlotsGenerated,
  });

  @override
  State<PreviewData> createState() => _PreviewDataState();
}

class _PreviewDataState extends State<PreviewData> {
  // Toggle switches
  bool _showPCA = true;
  bool _showUMAP = true;
  bool _showPHATE = true;

  double _nNeighbors = 15;
  int _nComponents = 2;
  double _minDist = 0.1;
  double _spread = 1.0;

  // Dropdown values
  String _selectedColor = 'parc_cluster';
  String _selectedColorScheme = 'viridis';

  List<String> get _colorOptions {
    final Set<String> options = {};

    final obsKeys = widget.adataInfo?['obs_keys'] as List? ?? [];
    if (obsKeys.isNotEmpty) {
      options.addAll(obsKeys.map((key) => '$key'));
    }

    final varNames = widget.adataInfo?['var_keys'] as List? ?? [];
    if (varNames.isNotEmpty) {
      options.addAll(varNames.map((key) => '$key'));
    }

    if (options.isEmpty) {
      return ['No observations or variables available'];
    }
    return options.toList();
  }

  final List<String> _colorSchemeOptions = [
    'viridis',
    'rainbow',
    'paired',
    'plasma',
    'inferno',
  ];

  @override
  void initState() {
    super.initState();
    if (_colorOptions.isNotEmpty && _colorOptions.first != 'No observations or variables available') {
      _selectedColor = _colorOptions.first;
    }
  }

  Future<void> _fetchPlots() async {
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = context.read<PipelineViewModel>();

    List<String> em = [];
    if (_showPCA) em.add('pca');
    if (_showUMAP) em.add('umap');
    if (_showPHATE) em.add('phate');

    if (em.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please select at least one plot type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedColor.isEmpty || _selectedColor == 'No observations or variables available') {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please select a valid color column'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final params = PreviewParams(
      jobId: widget.jobId,
      em: em,
      colorUmap: _selectedColor,
      colorScheme: _selectedColorScheme,
      nNeighbors: _nNeighbors,
      nComponents: _nComponents,
      minDist: _minDist,
      spread: _spread,
    );

    await viewModel.handlePreview(params);

    if (!mounted) return;

    if (viewModel.status == PipelineStatus.previewSuccess) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Plots loaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (viewModel.status == PipelineStatus.error && viewModel.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${viewModel.errorMessage}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PipelineViewModel>();
    final isLoading = viewModel.isLoading;
    final errorMessage = viewModel.errorMessage;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Controls Panel (40% width)
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.control_camera, color: Colors.black),
                      SizedBox(width: 8),
                      Text(
                        'Quality Control',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Select Plots:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('PCA'),
                          value: _showPCA,
                          onChanged: isLoading ? null : (value) => setState(() => _showPCA = value),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('UMAP'),
                          value: _showUMAP,
                          onChanged: isLoading ? null : (value) => setState(() => _showUMAP = value),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('PHATE'),
                          value: _showPHATE,
                          onChanged: isLoading ? null : (value) => setState(() => _showPHATE = value),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _colorOptions.contains(_selectedColor) ? _selectedColor : null,
                          decoration: InputDecoration(
                            labelText: _colorOptions.first != 'No observations or variables available'
                                ? 'Color (obs)'
                                : 'No observations available',
                            border: const OutlineInputBorder(),
                          ),
                          items: _colorOptions.map((color) {
                            return DropdownMenuItem(
                              value: color,
                              child: Text(color),
                            );
                          }).toList(),
                          onChanged: (_colorOptions.first != 'No observations or variables available' && !isLoading)
                              ? (value) => setState(() => _selectedColor = value!)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedColorScheme,
                          decoration: const InputDecoration(
                            labelText: 'Color Scheme',
                            border: OutlineInputBorder(),
                          ),
                          items: _colorSchemeOptions.map((scheme) {
                            return DropdownMenuItem(
                              value: scheme,
                              child: Text(scheme),
                            );
                          }).toList(),
                          onChanged: isLoading ? null : (value) => setState(() => _selectedColorScheme = value!),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UMAP Parameters',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text('Neighbors: ${_nNeighbors.toInt()}'),
                            ),
                            Expanded(
                              child: Slider(
                                value: _nNeighbors,
                                min: 2,
                                max: 100,
                                divisions: 98,
                                label: _nNeighbors.toInt().toString(),
                                onChanged: isLoading ? null : (value) => setState(() => _nNeighbors = value),
                              ),
                            ),
                          ],
                        ),

                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text('Components: $_nComponents'),
                            ),
                            Expanded(
                              child: Slider(
                                value: _nComponents.toDouble(),
                                min: 2,
                                max: 100,
                                divisions: 98,
                                label: _nComponents.toString(),
                                onChanged: isLoading ? null : (value) => setState(() => _nComponents = value.toInt()),
                              ),
                            ),
                          ],
                        ),

                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text('Min Dist: ${_minDist.toStringAsFixed(2)}'),
                            ),
                            Expanded(
                              child: Slider(
                                value: _minDist,
                                min: 0.01,
                                max: 0.99,
                                divisions: 98,
                                label: _minDist.toStringAsFixed(2),
                                onChanged: isLoading ? null : (value) => setState(() => _minDist = value),
                              ),
                            ),
                          ],
                        ),

                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text('Spread: ${_spread.toStringAsFixed(1)}'),
                            ),
                            Expanded(
                              child: Slider(
                                value: _spread,
                                min: 0.5,
                                max: 10.0,
                                divisions: 95,
                                label: _spread.toStringAsFixed(1),
                                onChanged: isLoading ? null : (value) => setState(() => _spread = value),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            const SizedBox(width: 20),

            Expanded(
              child: PlotCarousel(),
            ),
          ],
        ),

        if (errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              'Error: $errorMessage',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : _fetchPlots,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(isLoading ? 'Generating...' : 'Generate Plots'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.black38,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}