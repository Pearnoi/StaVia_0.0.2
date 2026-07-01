import 'package:flutter/material.dart';
import '../services/parc_service.dart';
import 'plot_display.dart';

class ParcControls extends StatefulWidget {
  final String jobId;

  const ParcControls({super.key, required this.jobId});

  @override
  State<ParcControls> createState() => _ParcControlsState();
}

class _ParcControlsState extends State<ParcControls> {
  // PARC Parameters
  int _nNeighbors = 10;
  int _nPcs = 40;
  double _jacStdGlobal = 0.15;
  int _randomSeed = 1;
  int _smallPop = 50;

  // UI State
  bool _isLoading = false;
  String? _parcPlot;
  String? _error;

  Future<void> _runParc() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _parcPlot = null;
    });

    try {
      final plot = await ParcService.runParc(
        jobId: widget.jobId,
        nNeighbors: _nNeighbors,
        nPcs: _nPcs,
        jacStdGlobal: _jacStdGlobal,
        randomSeed: _randomSeed,
        smallPop: _smallPop,
      );

      setState(() {
        _parcPlot = plot;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ PARC clustering complete!'),
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
          content: Text('❌ PARC failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Row(
          children: [
            Icon(Icons.graphic_eq_sharp, color: Colors.black),
            const SizedBox(width: 8),
            Text(
              'PARC Clustering',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'PARC: ultrafast and accurate clustering of phenotypic data of millions of single cells',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),

        // Parameters Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.4, 
                child: Column(
                  children: [
                    // n_neighbors
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text('Neighbors: $_nNeighbors'),
                        ),
                        Expanded(
                          child: Slider(
                            value: _nNeighbors.toDouble(),
                            min: 5,
                            max: 50,
                            divisions: 45,
                            label: _nNeighbors.toString(),
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _nNeighbors = value.toInt();
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                
                    // n_pcs
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text('PCs: $_nPcs'),
                        ),
                        Expanded(
                          child: Slider(
                            value: _nPcs.toDouble(),
                            min: 10,
                            max: 100,
                            divisions: 90,
                            label: _nPcs.toString(),
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _nPcs = value.toInt();
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                
                    // jac_std_global
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text('Jac Std: ${_jacStdGlobal.toStringAsFixed(2)}'),
                        ),
                        Expanded(
                          child: Slider(
                            value: _jacStdGlobal,
                            min: 0.01,
                            max: 0.5,
                            divisions: 49,
                            label: _jacStdGlobal.toStringAsFixed(2),
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _jacStdGlobal = value;
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                
                    // random_seed
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text('Random Seed: $_randomSeed'),
                        ),
                        Expanded(
                          child: Slider(
                            value: _randomSeed.toDouble(),
                            min: 1,
                            max: 100,
                            divisions: 99,
                            label: _randomSeed.toString(),
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _randomSeed = value.toInt();
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                
                    // small_pop
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text('Small Pop: $_smallPop'),
                        ),
                        Expanded(
                          child: Slider(
                            value: _smallPop.toDouble(),
                            min: 10,
                            max: 200,
                            divisions: 190,
                            label: _smallPop.toString(),
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _smallPop = value.toInt();
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

               // PARC Plot
              if (_parcPlot != null && !_isLoading) ...[
                PlotDisplay(
                  base64Image: _parcPlot,
                  title: 'PARC Clustering Results',
                  height: double.infinity,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Left: Annotations | Right: PARC Clusters',
                          style: TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Run Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _runParc,
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
            label: Text(_isLoading ? 'Running PARC...' : 'Run PARC Clustering'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.black38,
              foregroundColor: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 16),

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
      ],
    );
  }
}