import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/all_viewmodel.dart';
import '../parameters/params.dart';
import 'plot_display.dart';

class ViaControls extends StatefulWidget {
  final String jobId;
  final Function(Map<String, String>)? onPlotsGenerated;

  const ViaControls({
    super.key, 
    required this.jobId, 
    this.onPlotsGenerated,
  });

  @override
  State<ViaControls> createState() => _ViaControlsState();
}

class _ViaControlsState extends State<ViaControls> {
  // Text fields
  final TextEditingController _varNamesController = TextEditingController();
  final TextEditingController _obsController = TextEditingController();

  // Slider values
  double _knn = 30;
  double _clusterGraphPruning = 0.9;
  double _edgebundlePruning = 0.9;
  double _edgepruningClusteringResolution = 1.0;

  // DPI options
  int _selectedDpi = 120;
  final List<int> _dpiOptions = [72, 120, 300];

  // PAR options (switches)
  bool _timeSeries = false;
  bool _rnaVelocity = false;
  bool _spatialTemporal = false;
  bool _cytometry = false;

  Future<void> _runAnalysis(PipelineViewModel viewModel) async {
    List<String> parOption = [];
    if (_timeSeries) parOption.add('time-series');
    if (_rnaVelocity) parOption.add('rna-velocity');
    if (_spatialTemporal) parOption.add('spatial-temporal');
    if (_cytometry) parOption.add('cytometry');

    final params = AnalyzeParams(
      jobId: widget.jobId,
      varNames: _varNamesController.text.isNotEmpty 
          ? _varNamesController.text 
          : null,
      knn: _knn.round(),
      clusterGraphPruning: _clusterGraphPruning,
      edgebundlePruning: _edgebundlePruning,
      edgepruningClusteringResolution: _edgepruningClusteringResolution,
      dpi: _selectedDpi,
      obs: _obsController.text.isNotEmpty 
          ? _obsController.text 
          : null,
      parOption: parOption,
    );

    await viewModel.handleAnalysis(params);

    if (!mounted) return;

    if (viewModel.status == PipelineStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Analysis failed: ${viewModel.errorMessage}'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (viewModel.lastAnalysisResult != null) {
      final result = viewModel.lastAnalysisResult!;
      
      if (widget.onPlotsGenerated != null && result['plots'] != null) {
        final plots = Map<String, dynamic>.from(result['plots']);
        final Map<String, String> stringPlots = {};
        plots.forEach((key, value) {
          if (value is String && value.isNotEmpty) {
            stringPlots[key] = value;
          }
        });
        if (stringPlots.isNotEmpty) {
          widget.onPlotsGenerated!(stringPlots);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ VIA analysis complete!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _varNamesController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Widget _buildPlots(Map<String, dynamic>? analysisResult) {
    try {
      final plotsData = analysisResult?['plots'];
      
      if (plotsData == null) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Analysis completed successfully!',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ),
            ],
          ),
        );
      }

      Map<String, dynamic> plots = {};
      if (plotsData is Map) {
        plots = Map<String, dynamic>.from(plotsData);
      } 
      
      if (plots.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Analysis completed successfully!',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ),
            ],
          ),
        );
      }

      List<Widget> plotWidgets = [];

      void addPlot(String key, String title, {double height = 400}) {
        if (plotWidgets.isNotEmpty) {
          plotWidgets.add(const SizedBox(width: 16)); 
        }
        if (plots[key] != null && plots[key] is String) {
          final imageData = plots[key] as String;
          if (imageData.isNotEmpty) {
            plotWidgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: PlotDisplay(
                  base64Image: imageData,
                  title: title,
                  height: height,
                ),
              ),
            );
          }
        }
      }

      addPlot('atlas', 'VIA Atlas Embedding');
      addPlot('via', 'VIA Graph (Piechart)', height: 500);
      addPlot('lineage', 'Lineage Probability');
      addPlot('heat', 'Gene Trend Heatmaps');
      addPlot('exp', 'Gene Expression');
      addPlot('em', 'Velocity Embedding');
      addPlot('grid', 'Velocity Grid');
      addPlot('cl', 'Velocity Graph (Clusters)');
      addPlot('vel', 'RNA Velocity & Gene Expression');
      addPlot('stream', 'VIA Streamplot');
      addPlot('spa', 'Spatial Clusters');
      addPlot('mds', 'MDS Embedding');
      addPlot('cyto', 'Cytometry Streamplot');
      addPlot('cyto_test', 'Cytometry Test Plot');
      addPlot('velocity_error', 'Velocity Error', height: 300);
      addPlot('cyto_error', 'Cytometry Error', height: 300);

      if (plotWidgets.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Analysis completed but no plots were generated. Try enabling more analysis types.',
                  style: TextStyle(color: Colors.orange.shade700),
                ),
              ),
            ],
          ),
        );
      }

      return Row(
        children: [
          const SizedBox(width: 16),
          ...plotWidgets,
        ],
      );

    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          'Error displaying plots: $e',
          style: TextStyle(color: Colors.red.shade700),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PipelineViewModel>();
    final isLoading = viewModel.isLoading;
    final analysisResult = viewModel.lastAnalysisResult;
    final errorMessage = viewModel.errorMessage;

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🧬 VIA Analysis',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'VIA: Visualization and Inference of cellular trajectories',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
              
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _varNamesController,
                          decoration: const InputDecoration(
                            labelText: 'Variable Names',
                            hintText: 'e.g., gene1,gene2',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _obsController,
                          decoration: const InputDecoration(
                            labelText: 'Observation',
                            hintText: 'e.g., cell_type',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
              
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text('KNN: ${_knn.round()}'),
                            ),
                            Expanded(
                              child: Slider(
                                value: _knn,
                                min: 10,
                                max: 30,
                                divisions: 20,
                                label: _knn.round().toString(),
                                onChanged: (value) {
                                  setState(() {
                                    _knn = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                'Cluster Pruning: ${_clusterGraphPruning.toStringAsFixed(2)}',
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _clusterGraphPruning,
                                min: 0.1,
                                max: 1.0,
                                divisions: 50,
                                label: _clusterGraphPruning.toStringAsFixed(2),
                                onChanged: (value) {
                                  setState(() {
                                    _clusterGraphPruning = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                'Edgebundle: ${_edgebundlePruning.toStringAsFixed(2)}',
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _edgebundlePruning,
                                min: 0.1,
                                max: 1.0,
                                divisions: 50,
                                label: _edgebundlePruning.toStringAsFixed(2),
                                onChanged: (value) {
                                  setState(() {
                                    _edgebundlePruning = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                'Clustering Res: ${_edgepruningClusteringResolution.toStringAsFixed(2)}',
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _edgepruningClusteringResolution,
                                min: 0.1,
                                max: 1.0,
                                divisions: 50,
                                label: _edgepruningClusteringResolution.toStringAsFixed(2),
                                onChanged: (value) {
                                  setState(() {
                                    _edgepruningClusteringResolution = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
              
                  Row(
                    children: [
                      const Text(
                        'DPI: ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      ..._dpiOptions.map((dpi) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(dpi.toString()),
                            selected: _selectedDpi == dpi,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) _selectedDpi = dpi;
                              });
                            },
                            selectedColor: Colors.blue.shade100,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
              
                  const Text(
                    'Analysis Types:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    children: [
                      SwitchListTile(
                        title: const Text('Time Series'),
                        value: _timeSeries,
                        onChanged: (value) {
                          setState(() {
                            _timeSeries = value;
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      SwitchListTile(
                        title: const Text('RNA Velocity'),
                        value: _rnaVelocity,
                        onChanged: (value) {
                          setState(() {
                            _rnaVelocity = value;
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      SwitchListTile(
                        title: const Text('Spatio-Temporal'),
                        value: _spatialTemporal,
                        onChanged: (value) {
                          setState(() {
                            _spatialTemporal = value;
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      SwitchListTile(
                        title: const Text('Cytometry'),
                        value: _cytometry,
                        onChanged: (value) {
                          setState(() {
                            _cytometry = value;
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
        
            if (analysisResult != null && !isLoading) ...[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 16),
                      Container(
                        child: _buildPlots(analysisResult),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : () => _runAnalysis(viewModel),
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
            label: Text(isLoading ? 'Running VIA...' : 'Run VIA Analysis'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
    
        if (errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
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
      ],
    );
  }
}