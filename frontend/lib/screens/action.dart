import 'package:flutter/material.dart';
import 'package:stavia_ff/widgets/adata_show.dart';
import 'package:stavia_ff/widgets/file_upload.dart';
import 'package:stavia_ff/widgets/lightdarkmode.dart';
import 'package:stavia_ff/widgets/navigation_drawer.dart';
import 'package:stavia_ff/widgets/preprocess.dart';
import 'package:stavia_ff/widgets/preview_data.dart';
import 'package:stavia_ff/widgets/parc_controls.dart';
import 'package:stavia_ff/widgets/via_controls.dart';
import 'package:stavia_ff/widgets/download_plots_button.dart';

class ActionPage extends StatefulWidget {
  const ActionPage({super.key});

  @override
  State<ActionPage> createState() => _ActionPageState();
}

class _ActionPageState extends State<ActionPage> {
  Map<String, dynamic>? uploadData;
  Map<String, dynamic>? preprocessData;
  String? _jobId;
  Map<String, String> _plotData = {};

  void _handleUploadStart() {
    setState(() {
      uploadData = null;
      preprocessData = null;
      _jobId = null;
    });
  }

  void _handleUploadComplete(Map<String, dynamic> data) {
    setState(() {
      uploadData = data;
      preprocessData = null;
      _jobId = data['job_id']?.toString();
      
      // If job_id is not in the response, check if it's in the nested data
      if (_jobId == null && data['data'] != null) {
        _jobId = data['data']['job_id']?.toString();
      }
      
      print('🔵 Job ID received: $_jobId');
    });
  }

  void _handleUploadError(String error) {
    print('Upload error: $error');
    setState(() {
      _jobId = null;
    });
  }

  void _handlePreprocessComplete(Map<String, dynamic> data) { 
    setState(() {
      preprocessData = data;
    });
    print('✅ Preprocess data received: $data');
  }

  void _handlePlotsGenerated(Map<String, String> newPlots) {
    setState(() {
      _plotData.addAll(newPlots);
    });
    print('✅ Main state updated with new plots. Total plots: ${_plotData.length}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomNavigationDrawer(),
      appBar: AppBar(
        title: const Text('Action'),
        backgroundColor: Colors.black38,
        actions: [LightDarkMode()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              children: [
                FilePickerTest(
                  onUploadStart: _handleUploadStart,
                  onUploadComplete: _handleUploadComplete,
                  onUploadError: _handleUploadError,
                ),
                
                if (uploadData != null) ...[
                  const SizedBox(height: 20),
                  AdataCard(data: uploadData!, cardType: 'Upload',),
                ],
            
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                Preprocess(
                  jobId: _jobId ?? '',
                  onComplete: _handlePreprocessComplete, 
                ),
            
                if (preprocessData != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                    child: Column(children: [
                      const SizedBox(height: 10),
                      AdataCard(data: preprocessData!, cardType: 'Preprocess'),
                    ],
                  )
                ),
                ],
            
                // PARC
                if (_jobId != null && _jobId!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    ParcControls(jobId: _jobId!),
                  ],         
            
                // QUALITY CONTROL 
                if (_jobId != null && _jobId!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  PreviewData(
                    jobId: _jobId!,
                    adataInfo: preprocessData?['adata_info'] ?? uploadData?['adata_info'],
                    onPlotsGenerated: _handlePlotsGenerated, 
                  ),
                ], 
            
                // VIA ANALYSIS 
                if (_jobId != null && _jobId!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  ViaControls(
                    jobId: _jobId!,
                    onPlotsGenerated: _handlePlotsGenerated,
                  ),
                ],
            
                const SizedBox(height: 20),
                
                // DOWNLOAD BUTTON 
                DownloadPlotsButton(
                  plotData: Map.from(_plotData), 
                  jobId: _jobId,
                ),
                
                const SizedBox(height: 20)
              ],
            ),
          ),
        ),
      ),
    );
  }
}