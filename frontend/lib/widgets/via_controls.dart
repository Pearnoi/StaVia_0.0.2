import 'package:flutter/material.dart';
import '../services/analyze_service.dart';
import 'plot_display.dart';

class ViaControls extends StatefulWidget {
  final String jobId;
  final Function(Map<String, String>)? onPlotsGenerated;

  const ViaControls({super.key, required this.jobId, this.onPlotsGenerated,});

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

  // UI State
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _analysisResult;

  Future<void> _runAnalysis() async {
    // Build par_option list from switches
    List<String> parOption = [];
    if (_timeSeries) parOption.add('time-series');
    if (_rnaVelocity) parOption.add('rna-velocity');
    if (_spatialTemporal) parOption.add('spatial-temporal');
    if (_cytometry) parOption.add('cytometry');

    setState(() {
      _isLoading = true;
      _error = null;
      _analysisResult = null;
    });

    try {
      final result = await AnalyzeService.runAnalysis(
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

      setState(() {
        _analysisResult = result;
        _isLoading = false;
      });

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
          print('✅ VIA plots sent to parent: ${stringPlots.keys}');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ VIA analysis complete!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Analysis failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleVIAResult(Map<String, dynamic> result) {
    print('✅ VIA analysis complete');
    
    // Extract plots from VIA result
    final plots = Map<String, String>.from(result['plots'] ?? {});
    
    // Notify parent
    if (widget.onPlotsGenerated != null && plots.isNotEmpty) {
      widget.onPlotsGenerated!(plots);
    }
  }

  @override
  void dispose() {
    _varNamesController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Widget _buildPlots() {
    try {
      // Get the plots data safely
      final plotsData = _analysisResult?['plots'];
      
      // If no plots data, show success message
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

      // If plotsData is already a Map, use it directly
      Map<String, dynamic> plots = {};
      
      if (plotsData is Map) {
        plots = Map<String, dynamic>.from(plotsData);
      } 
      
      // If plots is empty, show success message
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

      // Build all plots
      List<Widget> plotWidgets = [];

      // Helper to add plot
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

      // Add all available plots
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

      // If no plots were added, show message
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

      // Return all plots
      return Row(
        children: [
          const SizedBox(width: 16),
          ...plotWidgets,
        ],
      );

    } catch (e) {
      print('❌ Error building plots: $e');
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
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
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
              
                  // ============================================
                  // 1. TEXT FIELDS (var_names and obs)
                  // ============================================
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
              
                  // ============================================
                  // 2. SLIDERS
                  // ============================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // knn
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
              
                        // cluster_graph_pruning
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
              
                        // edgebundle_pruning
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
              
                        // edgepruning_clustering_resolution
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
              
                  // ============================================
                  // 3. DPI OPTIONS (Choosable Tabs)
                  // ============================================
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
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 16),
              
                  // ============================================
                  // 4. PAR OPTIONS (Switches)
                  // ============================================
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
        
            if (_analysisResult != null && !_isLoading) ...[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 16),
                      Container(
                        child: _buildPlots(),
                      ),
                    ]
                  ),
                ),
              ),
            ],
          ],
        ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _runAnalysis,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_isLoading ? 'Running VIA...' : 'Run VIA Analysis'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
    
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              'Error: $_error',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
      ],
    );
  }
}