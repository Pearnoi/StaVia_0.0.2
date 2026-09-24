import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../viewmodel/all_viewmodel.dart';

class PlotCarousel extends StatefulWidget {
  const PlotCarousel({super.key});

  @override
  State<PlotCarousel> createState() => _PlotCarouselState();
}

class _PlotCarouselState extends State<PlotCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PipelineViewModel>();
    final interactivePlots = viewModel.previewResult?.interactivePlots ?? {};

    if (interactivePlots.isEmpty) {
      return Container(
        height: 420,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Text(
            'Configure parameters and tap "Generate Plots"',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final keys = interactivePlots.keys.toList();

    return Column(
      children: [
        SizedBox(
          height: 420,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final plotType = keys[index];
              final htmlContent = interactivePlots[plotType] ?? '';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        plotType.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: InAppWebView(
                        // Re-renders the WebView when the HTML payload updates
                        key: ValueKey('${plotType}_${htmlContent.hashCode}'),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          domStorageEnabled: true,
                          transparentBackground: true,
                        ),
                        onWebViewCreated: (controller) {
                          controller.loadData(
                            data: htmlContent,
                            mimeType: 'text/html',
                            encoding: 'utf-8',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            keys.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 12 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}