import 'package:flutter/material.dart';
import 'package:flutter_toggle_tab/flutter_toggle_tab.dart';
import '../services/preprocess_service.dart'; 

class Preprocess extends StatefulWidget {
  final String jobId; 
  final Function(Map<String, dynamic>)? onComplete;

  const Preprocess({super.key, required this.jobId, this.onComplete});

  @override
  State<Preprocess> createState() => _PreprocessState();
}

class _PreprocessState extends State<Preprocess> {
  int _tabIconIndexSelected = 0;
  final TextEditingController _orderController = TextEditingController(text: '12345');
  
  bool _isProcessing = false;

  final List<DataTab> _listIconTabToggle = [
    DataTab(title: "Default"),
    DataTab(title: "Custom"),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(Icons.run_circle, color: Colors.black),
            const SizedBox(width: 8),
            Text(
              'Data Preprocessing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 10,), 
        // Toggle Tab
        Center(
          child: FlutterToggleTab(
            width: 80,
            borderRadius: 15,
            selectedIndex: _tabIconIndexSelected,
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            unSelectedTextStyle: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            dataTabs: _listIconTabToggle,
            selectedLabelIndex: (index) {
              setState(() {
                _tabIconIndexSelected = index;
              });
            },
            marginSelected: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Show Custom Order Input when Custom tab is selected
        if (_tabIconIndexSelected == 1) ...[
          Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered, color: Colors.blue),
                const SizedBox(width: 12),
                const Text(
                  'Order: ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _orderController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., 12345',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      counterText: '',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    enabled: !_isProcessing,
                    onChanged: (value) {
                      // Validate input - only allow numbers 1-5
                      final filtered = value.replaceAll(RegExp(r'[^1-5]'), '');
                      if (filtered != value) {
                        _orderController.value = TextEditingValue(
                          text: filtered,
                          selection: TextSelection.collapsed(offset: filtered.length),
                        );
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: _isProcessing ? null : () {
                    _orderController.text = '12345';
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Reset to default order',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Enter numbers 1-5 for preprocessing steps in order:\n1=Cell Filtering, 2=Gene Filtering, 3=Data Normalization, 4=Log Normalization, 5=PCA',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),
        ],
        
        // Show Default Info when Default tab is selected
        if (_tabIconIndexSelected == 0) ...[
          Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default preprocessing order: Filter Cells → Filter Genes → Data normalization → Log Transform → PCA Embedding Calculation',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 20),
        
        // Process Button
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _processPreprocess,
          icon: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.play_arrow),
          label: Text(_isProcessing ? 'Processing...' : 'Run Preprocessing'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.black38,
              foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _processPreprocess() async {
    // Prevent multiple submissions
    if (_isProcessing) return;

    String order = '12345';
    String choice = 'default';
    
    if (_tabIconIndexSelected == 1) {
      // Custom mode
      order = _orderController.text.trim();
      if (order.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid order (e.g., 12345)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      choice = 'custom';
    }
    
    setState(() {
      _isProcessing = true;
    });

    try {
      print('🔵 Running preprocessing with choice: $choice, order: $order');
      
      // Call the service
      final result = await PreprocessService.runPreprocessing(
        jobId: widget.jobId,
        choice: choice,
        order: order,
      );

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Preprocessing complete! Dimensions: ${result.dimensions}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      if (widget.onComplete != null) {
        widget.onComplete!({
          'adata_info': {
            'dimensions': result.dimensions,
            'obs_keys': result.obsKeys,
            'var_keys': result.varKeys,
            'layers': result.layers,
            'uns_keys': result.unsKeys,
            'obsm_keys': result.obsmKeys,
            'varm_keys': result.varmKeys,
          }
        });
      }
   
    } catch (e) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Preprocessing failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      print('❌ Error: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _orderController.dispose();
    super.dispose();
  }
}