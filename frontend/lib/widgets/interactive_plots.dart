import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class InteractivePlot extends StatefulWidget {
  final String htmlContent;
  final double height;
  final double width;

  const InteractivePlot({
    super.key,
    required this.htmlContent,
    this.height = 400,
    this.width = 400,
  });

  @override
  State<InteractivePlot> createState() => _InteractivePlotState();
}

class _InteractivePlotState extends State<InteractivePlot> {
  late InAppWebViewController _controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Card(
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Interactive UMAP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: widget.htmlContent,
                  mimeType: 'text/html',
                  encoding: 'utf-8',
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onLoadStop: (controller, url) {
                  print('Interactive plot loaded');
                },
                onLoadError: (controller, url, code, message) {
                  print('Load error: $message');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}