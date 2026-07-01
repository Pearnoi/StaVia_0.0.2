// lib/widgets/plot_controls.dart
import 'package:flutter/material.dart';
import '../services/preview_service.dart';
import 'plot_display.dart';

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

  // Plot data
  Map<String, String?>? _plots;
  bool _isLoading = false;
  String? _error;

  List<String> get _colorOptions {
    Set<String> options = {}; // ← Use Set instead of List
    
    // Add obs_keys
    final obsKeys = widget.adataInfo?['obs_keys'] as List? ?? [];
    if (obsKeys.isNotEmpty) {
      options.addAll(obsKeys.map((key) => '$key'));
    }
    
    // Add var_keys
    final varNames = widget.adataInfo?['var_keys'] as List? ?? [];
    if (varNames.isNotEmpty) {
      options.addAll(varNames.map((key) => '$key'));
    }
    
    if (options.isEmpty) {
      return ['No observations or variables available'];
    }
    return options.toList(); // ← Convert back to List
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
    if (_colorOptions.isNotEmpty && _colorOptions.first != 'No observations available') {
      _selectedColor = _colorOptions.first;
    }
  }

  Future<void> _fetchPlots() async {
    // Build the em list based on switches
    List<String> em = [];
    if (_showPCA) em.add('pca');
    if (_showUMAP) em.add('umap');
    if (_showPHATE) em.add('phate');

    if (em.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one plot type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedColor.isEmpty || _selectedColor == 'No observations available') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid color column'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await PreviewService.getPlots(
        jobId: widget.jobId,
        em: em,
        colorUmap: _selectedColor,
        colorScheme: _selectedColorScheme,
        nNeighbors: _nNeighbors,
        nComponents: _nComponents,
        minDist: _minDist,
        spread: _spread,
      );

      setState(() {
        _plots = response.plots;
        _isLoading = false;
      });

      if (widget.onPlotsGenerated != null && _plots != null && _plots!.isNotEmpty) {
        final Map<String, String> plots = _plots!.map((key, value) => MapEntry(key, value ?? ''));
        widget.onPlotsGenerated!(plots);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Plots loaded successfully!'),
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
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
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
                  Row(
                    children: [
                      Icon(Icons.control_camera, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        'Quality Control',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20,),
                  // Plot toggles
                  const Text(
                    'Select Plots:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('PCA'),
                          value: _showPCA,
                          onChanged: (value) {
                            setState(() {
                              _showPCA = value;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('UMAP'),
                          value: _showUMAP,
                          onChanged: (value) {
                            setState(() {
                              _showUMAP = value;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('PHATE'),
                          value: _showPHATE,
                          onChanged: (value) {
                            setState(() {
                              _showPHATE = value;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    ],
                  ),
              
                  const SizedBox(height: 16),
              
                  // Color dropdown
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _colorOptions.contains(_selectedColor) ? _selectedColor : null,
                          decoration: InputDecoration(
                            labelText: _colorOptions.first != 'No observations available' 
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
                          onChanged: _colorOptions.first != 'No observations available' ? (value) {
                            setState(() {
                              _selectedColor = value!;
                            });
                          } : null,
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
                          onChanged: (value) {
                            setState(() {
                              _selectedColorScheme = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
              
                  // After the color dropdowns (around line 150)
                  const SizedBox(height: 16),
              
                  // UMAP Parameters Section
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
                        
                        // n_neighbors slider
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
                                onChanged: (value) {
                                  setState(() {
                                    _nNeighbors = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        // n_components slider
                        // n_components slider - SAFER VERSION
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
                                onChanged: (value) {
                                  setState(() {
                                    _nComponents = value.toInt();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        // min_dist slider
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
                                onChanged: (value) {
                                  setState(() {
                                    _minDist = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        // spread slider
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
                                onChanged: (value) {
                                  setState(() {
                                    _spread = value;
                                  });
                                },
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
        
            if (_plots != null && !_isLoading) ...[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 16),
                      // PCA Plot
                      if (_plots!['pca'] != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: SizedBox(
                            width: 400, 
                            child: PlotDisplay(
                              base64Image: _plots!['pca'],
                              title: 'PCA Variance Ratio',
                              height: 300,
                            ),
                          ),
                        ),
                      
                      // UMAP Plot
                      if (_plots!['umap'] != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: SizedBox(
                            width: 400,
                            child: PlotDisplay(
                              base64Image: _plots!['umap'],
                              title: 'UMAP Embedding',
                              height: 400,
                            ),
                          ),
                        ),
                      
                      // PHATE Plot
                      if (_plots!['phate'] != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: SizedBox(
                            width: 400,
                            child: PlotDisplay(
                              base64Image: _plots!['phate'],
                              title: 'PHATE Embedding',
                              height: 400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

        // Error message
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

        // Generate button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _fetchPlots,
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
            label: Text(_isLoading ? 'Generating...' : 'Generate Plots'),
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