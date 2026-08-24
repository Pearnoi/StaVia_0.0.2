import pyVIA.core as via 
import pandas as pd 
import scanpy as sc 
import umap, phate, warnings, random
import matplotlib as mpl 
import traceback
mpl.use('Agg')
warnings.filterwarnings('ignore') 

from params import JobConfig, VIAParams
from anndata import AnnData

def run_via_analysis(adata: AnnData, params: VIAParams, file_data: JobConfig = None):
    try:
        knn = params.knn
        cluster_graph_pruning = params.clusterGraphPruning
        edgepruning_clustering_resolution = params.edgePruningClusteringResolution
        edgebundle_pruning = params.edgeBundlePruning
        adata_obs = params.obs 
      
        data_categories = params.parOption or []
        time_series = 'time-series' in data_categories
        use_velocity = 'rna-velocity' in data_categories
        do_spatial = 'spatial-temporal' in data_categories
        do_cytometry = 'cytometry' in data_categories

        metadata = file_data.metadata if (file_data and file_data.metadata) else {}
        time_series_content = metadata.get('time_series')              
        velocity_matrix_content = metadata.get('velocity')            
        root_upload_content = metadata.get('root')                     
        true_label_content = metadata.get('annotation')               
        spatial_coords_content = metadata.get('spatial')     
        cytometry_file_features = metadata.get('cytometry_features')             
        cytometry_file_content = metadata.get('cytometry_phase')   

        true_label = None
        if true_label_content:
            true_label = true_label_content
        else: 
            if "annotation" in adata.obs:
                true_label = adata.obs["annotation"]
            if "PARC" in adata.obs:
                true_label = adata.obs["PARC"]
            else: 
                true_label = adata.obs.get(adata_obs)

        time_series_labels = time_series_content if time_series_content else None 
        
        if root_upload_content:
            root_user = root_upload_content
        else: 
            gene = random.choice(adata.var_names.tolist())
            print(f"DEBUG: Selected random gene: '{gene}'")
            print(f"DEBUG: Gene type: {type(gene)}")
            print(f"DEBUG: Gene in var_names? {gene in adata.var_names}")
            root_user = [adata[:, gene].X.argmax()]
        
        # ------- Initialize Parameters --------
        n_pcs = 50
        ncomp = 50 
        random_seed = 0 
        small_pop = 2 
        too_big_factor = 0.3 
        memory = 50
        random_seed = 0

        # ----- Time Series Analysis --------
        if time_series: 
            time_series_labels = time_series_labels
        else:
            time_series_labels = None

        # ------- RNA Velocity ----------
        velocity_matrix = None
        gene_matrix = adata.X.todense() if hasattr(adata.X, 'todense') else adata.X
        velo_weight = 0

        if use_velocity and velocity_matrix_content is not None:
            try:
                velocity_df = velocity_matrix_content
                
                # 1. Match cells
                common_cells = velocity_df.index.intersection(adata.obs_names)
                if len(common_cells) == 0:
                    raise ValueError("No matching cells")
                
                velocity_df = velocity_df.loc[common_cells]
                adata = adata[common_cells]
                
                # 2. Match genes
                common_genes = list(set(adata.var_names) & set(velocity_df.columns))
                if len(common_genes) == 0:
                    raise ValueError("No matching genes")
                
                velocity_df = velocity_df[common_genes]
                adata = adata[:, common_genes]
                
                # 3. Convert to matrices
                gene_matrix = adata.X.toarray() if hasattr(adata.X, 'toarray') else adata.X
                velocity_matrix = velocity_df.values
                velo_weight = 0.5
                    
            except Exception as e:
                velocity_matrix = None
                velo_weight = 0

        # --------- Spatial Analysis -----------
        if do_spatial:
            if spatial_coords_content:
                coords = spatial_coords_content
            else:
                coords=adata.obsm['X_pca'] 

            spatial_knn_input = 6 
            spatial_weight = 0.3
            spatial_knn_trajectory =6
            X_spatial_exp = via.spatial_input(X_genes = adata.X, spatial_coords=coords, knn_spatial=spatial_knn_input, spatial_weight=spatial_weight)

            adata.obsm['X_spatial_adjusted'] = X_spatial_exp
            adata.obsm["spatial_pca"] = sc.tl.pca(adata.obsm['X_spatial_adjusted'],n_comps=n_pcs)

            print(f'end X_spatial input')
        else:
            spatial_knn_input = 0
            spatial_knn_trajectory = 0
            coords = None  
            spatial_weight = 0

        # --------- Cytometry Analysis ------------
        if do_cytometry:
            print(f"Type of cytometry_file: {type(cytometry_file_features)}")
            try:
                # Load and clean the cytometry data
                if 'Unnamed: 0' in cytometry_file_features.columns:
                    df = cytometry_file_features.drop('Unnamed: 0', axis=1)
                else:
                    df = cytometry_file_features
                
                df = df.dropna()
                print(f'Loaded cytometry file with shape: {df.shape}')
                true_label = cytometry_file_content
                true_label = list(true_label['phase'].values.flatten())
                print('There are ', len(true_label), 'MCF7 cells and ', df.shape[1], 'features')
                ad = sc.AnnData(df)
                ad.var_names = df.columns

                sc.pp.scale(ad)

                sc.tl.pca(ad, svd_solver='arpack')
                X_in = ad.X
                df_X = pd.DataFrame(X_in)

                df_X.columns = [i for i in ad.var_names]
                
                # # Scale specific features if they exist (like in reference code)
                if 'Area' in df_X.columns:
                    df_X['Area'] = df_X['Area'] * 3
                if 'Dry Mass' in df_X.columns:
                    df_X['Dry Mass'] = df_X['Dry Mass'] * 3
                if 'Volume' in df_X.columns:
                    df_X['Volume'] = df_X['Volume'] * 20
                print('Applied feature-specific scaling')

                X_in = df_X.values
                ad = sc.AnnData(df_X)

                sc.tl.pca(ad, svd_solver='arpack')
                ad.var_names = df_X.columns
                print('Applied PCA')

                cell_dict = {'T1_M1': 'yellow', 'T2_M1': 'yellowgreen', 'T1_M2': 'orange', 'T2_M2': 'darkgreen', 'T1_M3': 'red', 'T2_M3': 'blue'}
                cell_phase_dict = {'T1_M1': 'G1', 'T2_M1': 'G1', 'T1_M2': 'S', 'T2_M2': 'S', 'T1_M3': 'M/G2', 'T2_M3': 'M/G2'}

                knn = 20
                random_seed = 1
                true_label = [cell_phase_dict[i] for i in true_label]
            except Exception as e:
                print(f"Error processing cytometry CSV: {e}")
                traceback.print_exc()
                knn = 20
                random_seed = 1
                root_user = None
                true_label = None
                raise 

        if 'PARC' in adata.obs.columns: 
            embedding = adata.obs['PARC']
            true_label = adata.obs['annotation']
        else:
            embedding = adata.obsm['X_pca'][:,:ncomp]
    
        print('RUN VIA')
        v0 = via.VIA(embedding, true_label = true_label, memory = memory,
                    edgepruning_clustering_resolution=edgepruning_clustering_resolution, 
                    edgepruning_clustering_resolution_local=1, knn=knn,
                    too_big_factor=too_big_factor, root_user=root_user,
                    cluster_graph_pruning=cluster_graph_pruning, 
                    edgebundle_pruning_twice = False, time_series=time_series, time_series_labels=time_series_labels,
                    edgebundle_pruning = edgebundle_pruning,
                    small_pop = small_pop, velo_weight=velo_weight, velocity_matrix=velocity_matrix, gene_matrix=gene_matrix,
                    piegraph_arrow_head_width=0.07,
                    random_seed=random_seed,
                    resolution_parameter=1,
                    is_coarse=True, 
                    x_lazy=0.99, alpha_teleport=0.99, 
                    viagraph_decay = 1.0, 
                    preserve_disconnected=False,
                    do_spatial_knn=do_spatial, do_spatial_layout= do_spatial, spatial_coords = coords, spatial_knn=spatial_knn_trajectory)
        v0.run_VIA()
        if 'X_umap' in adata.obsm:
            v0.embedding = adata.obsm['X_umap'][:,:2]
        elif 'X_pca' in adata.obsm:
            v0.embedding = adata.obsm['X_pca'][:,:2]

        return {'via_obj': v0, 'adata': adata}
    
    except Exception as e:
        print("=== ERROR INSIDE RUN_VIA_ANALYSIS ===")
        traceback.print_exc()
        raise RuntimeError(f"run_via_analysis failed: {str(e)}") from e
    
# ------- Get embedding value for cytometry -----------
def via_analysis_embedding(params: VIAParams, file_data: JobConfig=None):
    print("Calculating embedding")
    data_categories = params.parOption or []
    do_cytometry = 'cytometry' in data_categories
    metadata = file_data.metadata if (file_data and file_data.metadata) else {}
    cytometry_file_features = metadata.get('cytometry_features')

    if do_cytometry:
        # Load and clean the cytometry data
        if 'Unnamed: 0' in cytometry_file_features.columns:
            df = cytometry_file_features.drop('Unnamed: 0', axis=1)
        else:
            df = cytometry_file_features
        
        df = df.dropna()
        ad = sc.AnnData(df)
        ad.var_names = df.columns

        sc.pp.scale(ad)
        sc.tl.pca(ad, svd_solver='arpack')
        X_in = ad.X
        df_X = pd.DataFrame(X_in)

        df_X.columns = [i for i in ad.var_names]
        
        # # Scale specific features if they exist (like in reference code)
        if 'Area' in df_X.columns:
            df_X['Area'] = df_X['Area'] * 3
        if 'Dry Mass' in df_X.columns:
            df_X['Dry Mass'] = df_X['Dry Mass'] * 3
        if 'Volume' in df_X.columns:
            df_X['Volume'] = df_X['Volume'] * 20
        print('Applied feature-specific scaling')

        X_in = df_X.values
        ad = sc.AnnData(df_X)
        sc.tl.pca(ad, svd_solver='arpack')
        ad.var_names = df_X.columns

        embedding = umap.UMAP().fit_transform(ad.obsm['X_pca'][:, 0:20])
        phate_op = phate.PHATE()
        embedding = phate_op.fit_transform(X_in)

        return embedding