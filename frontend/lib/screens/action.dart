import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stavia_ff/viewmodel/all_viewmodel.dart';
import 'package:stavia_ff/widgets/adata_show.dart';
import 'package:stavia_ff/widgets/file_upload.dart';
import 'package:stavia_ff/widgets/lightdarkmode.dart';
import 'package:stavia_ff/widgets/navigation_drawer.dart';
import 'package:stavia_ff/widgets/preprocess.dart';
import 'package:stavia_ff/widgets/preview_data.dart';
import 'package:stavia_ff/widgets/parc_controls.dart';
import 'package:stavia_ff/widgets/via_controls.dart';
import 'package:stavia_ff/widgets/download_plots_button.dart';

class ActionPage extends StatelessWidget {
  const ActionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PipelineViewModel>();
    final jobId = viewModel.jobId;
    final uploadData = viewModel.uploadResult;
    final preprocessData = viewModel.preprocessingResult;

    final hasValidJob = jobId != null && jobId.isNotEmpty;

    return Scaffold(
      drawer: const CustomNavigationDrawer(),
      appBar: AppBar(
        title: const Text('Action'),
        backgroundColor: Colors.black38,
        actions: const [LightDarkMode()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              children: [
                const FilePickerTest(),

                if (uploadData != null) ...[
                  const SizedBox(height: 20),
                  AdataCard(data: uploadData, cardType: 'Upload'),
                ],

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),

                if (hasValidJob) ...[
                  Preprocess(jobId: jobId),
                  if (preprocessData != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          AdataCard(data: preprocessData, cardType: 'Preprocess'),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  ParcControls(jobId: jobId),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  PreviewData(
                    jobId: jobId,
                    adataInfo: preprocessData?['adata_info'] ?? uploadData?['adata_info'],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  ViaControls(jobId: jobId),

                  const SizedBox(height: 20),
                  const DownloadPlotsButton(),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}