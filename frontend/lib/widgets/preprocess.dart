import 'package:flutter/material.dart';
import 'package:flutter_toggle_tab/flutter_toggle_tab.dart';
import 'package:provider/provider.dart';
import '../viewmodel/all_viewmodel.dart';
import '../parameters/params.dart';

class Preprocess extends StatefulWidget {
  final String jobId;

  const Preprocess({super.key, required this.jobId});

  @override
  State<Preprocess> createState() => _PreprocessState();
}

class _PreprocessState extends State<Preprocess> {
  int _tabIconIndexSelected = 0;
  final TextEditingController _orderController = TextEditingController(text: '12345');

  final List<DataTab> _listIconTabToggle = [
    DataTab(title: "Default"),
    DataTab(title: "Custom"),
  ];

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PipelineViewModel>();
    final isProcessing = viewModel.isLoading;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Row(
          children: [
            Icon(Icons.run_circle, color: Colors.black),
            SizedBox(width: 8),
            Text(
              'Data Preprocessing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

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
                    enabled: !isProcessing,
                    onChanged: (value) {
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
                  onPressed: isProcessing ? null : () => _orderController.text = '12345',
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
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Default preprocessing order: Filter Cells → Filter Genes → Data normalization → Log Transform → PCA Embedding Calculation',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: isProcessing ? null : () => _processPreprocess(context),
          icon: isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.play_arrow),
          label: Text(isProcessing ? 'Processing...' : 'Run Preprocessing'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: Colors.black38,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _processPreprocess(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = context.read<PipelineViewModel>();

    String order = '12345';
    String choice = 'default';

    if (_tabIconIndexSelected == 1) {
      order = _orderController.text.trim();
      if (order.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid order (e.g., 12345)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      choice = 'custom';
    }

    final params = PreprocessParams(
      jobId: widget.jobId,
      choice: choice,
      order: order,
    );

    await viewModel.handlePreprocessing(params);

    if (!context.mounted) return;

    if (viewModel.status == PipelineStatus.preprocessing) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Preprocessing complete!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else if (viewModel.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Preprocessing failed: ${viewModel.errorMessage}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _orderController.dispose();
    super.dispose();
  }
}