// Preprocess Params 
class PreprocessParams {
  final String jobId;
  final String choice;
  final String order;

  PreprocessParams({
    required this.jobId,
    this.choice = 'default',
    this.order = '12345',
  });

  Map<String, dynamic> toJson() {
    return {
      'preprocessChoice': choice,
      'order': order,
    };
  }
}

// Preview Params and Response 
class PreviewParams {
  final String jobId;
  final List<String> em; 
  final String colorUmap;
  final String colorScheme;
  final double nNeighbors;
  final int nComponents;
  final double minDist;
  final double spread;

  PreviewParams({
    required this.jobId,
    this.em = const ['pca', 'umap', 'phate'],
    required this.colorUmap,
    this.colorScheme = 'viridis',
    this.nNeighbors = 15.0,
    this.nComponents = 2,
    this.minDist = 0.5,
    this.spread = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'em': em.join(','),
      'color_umap': colorUmap,
      'color_scheme': colorScheme,
      'n_neighbors': nNeighbors,
      'n_components': nComponents,
      'min_dist': minDist,
      'spread': spread,
    };
  }
}

class PreviewResponse {
  final Map<String, String?> interactivePlots; 

  PreviewResponse({
    required this.interactivePlots,
  });

  factory PreviewResponse.fromJson(Map<String, dynamic> json) {
    final rawPlots = json['plots'] ?? json; 

    Map<String, String> parsedPlots = {};
    if (rawPlots is Map) {
      rawPlots.forEach((key, value) {
        if (value != null) {
          parsedPlots[key.toString()] = value.toString();
        }
      });
    }

    return PreviewResponse(
      interactivePlots: parsedPlots,
    );
  }
}

// Analyze Params 
class AnalyzeParams {
  final String jobId;
  final int knn;
  final double clusterGraphPruning;
  final double edgebundlePruning;
  final double edgepruningClusteringResolution;
  final int dpi;
  final String? varNames;
  final String? obs;
  final List<String> parOption;

  AnalyzeParams({
    required this.jobId,
    this.knn = 30,
    this.clusterGraphPruning = 0.15,
    this.edgebundlePruning = 0.85,
    this.edgepruningClusteringResolution = 1.0,
    this.dpi = 150,
    this.varNames,
    this.obs,
    this.parOption = const [],
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'knn': knn,
      'cluster_graph_pruning': clusterGraphPruning,
      'edgebundle_pruning': edgebundlePruning,
      'edgepruning_clustering_resolution': edgepruningClusteringResolution,
      'dpi': dpi,
      'par_option': parOption,
    };

    if (varNames != null && varNames!.isNotEmpty) {
      json['var_names'] = varNames;
    }
    if (obs != null && obs!.isNotEmpty) {
      json['obs'] = obs;
    }

    return json;
  }
}