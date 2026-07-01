import pyVIA.core as via 
import pandas as pd 
import numpy as np 
import scanpy as sc 
import scanpy.external as sce 
import anndata as ad 
import umap, phate, warnings, sys, os, glob, random, csv
import matplotlib.pyplot as plt 
import matplotlib as mpl 
mpl.use('Agg')
from matplotlib.pyplot import rc_context 
import seaborn as sns 
from sklearn.manifold import TSNE 
warnings.filterwarnings('ignore') 
from importlib import reload 
from collections import defaultdict
import scvelo as scv

from flask import jsonify
from io import BytesIO
import base64
import json

def run_via_analysis(adata, params, file_data = None):
    try:
        knn = int(params.get('knn', 30))
        cluster_graph_pruning = float(params.get('cluster_graph_pruning', 0.15))
        edgepruning_clustering_resolution = float(params.get('edgepruning_clustering_resolution', 0.15))
        edgebundle_pruning = float(params.get('edgebundle_pruning', 0.15))
        true_label = params.get('true_label', None)
        root_user = params.get('root_user', None)
        time_series_labels = params.get('time_series_labels', None)
        adata_obs = params.get('adata_obs', None)
      
        data_categories = params.get('par_option', [])
        time_series = 'time-series' in data_categories
        use_velocity = 'rna-velocity' in data_categories
        do_spatial = 'spatial-temporal' in data_categories
        do_cytometry = 'cytometry' in data_categories
        
        if file_data is not None: 
            time_series_file = file_data.get('time_series')              
            velocity_matrix_file = file_data.get('velocity')            
            gene_matrix_file = file_data.get('gene_matrix')              
            root_upload_file = file_data.get('root')                     
            true_label_file = file_data.get('annotation')               
            spatial_coords_file = file_data.get('spatial')               
            cytometry_file_features = file_data.get('cytometry_features') 
            cytometry_file_phase = file_data.get('cytometry_phase')   

        results = {}

        true_label = None
        if true_label_file:
            try:
                true_label = []
                reader = csv.reader(true_label_file)
                for row in reader:
                    if row:  
                        true_label.append(row[0])  
                if all(item.lstrip('-').isdigit() for item in true_label):
                    true_label = [int(item) for item in true_label]
            except Exception as e:
                print(f"Error processing true_label CSV: {e}")
                true_label = None
        else: 
            if true_label and isinstance(true_label, str):
                if true_label.lower() == 'none' and adata_obs.lower() == 'none':
                    true_label = None
                elif true_label.lower() != 'none' and adata_obs.lower() == 'none':
                    try:
                        true_label = [item.strip() for item in true_label.split(',')]
                        if all(item.lstrip('-').isdigit() for item in true_label):
                            true_label = [int(item) for item in true_label]
                    except Exception as e:
                        print(f"Error processing true_label: {e}")
                        true_label = None
                else:
                    if "annotation" in adata.obs:
                        true_label = adata.obs["annotation"]
                    if "PARC" in adata.obs:
                        true_label = adata.obs["PARC"]
                    else: 
                        true_label = adata.obs[adata_obs]

        if time_series_file:
            try:
                time_series_labels = []
                reader = csv.reader(time_series_file)
                for row in reader:
                    if row:  
                        time_series_labels.append(row[0])  
                if all(item.lstrip('-').isdigit() for item in time_series_labels):
                    time_series_labels = [int(item) for item in time_series_labels]
            except Exception as e:
                print(f"Error processing time series CSV: {e}")
                time_series_labels = None
        else: 
            if time_series_labels and isinstance(time_series_labels, str):
                if time_series_labels.lower() == 'none':
                    time_series_labels = None
                else:
                    try:
                        time_series_labels = [int(i.strip()) for i in time_series_labels.split(',') 
                                        if i.strip().isdigit()]
                    except Exception as e:
                        print(f"Error processing time_series_labels: {e}")
                        time_series_labels = None
        
        if root_upload_file:
            try:
                root_user = []
                reader = csv.reader(root_upload_file)
                for row in reader:
                    if row:  
                        root_user.append(row[0])  
                if all(item.lstrip('-').isdigit() for item in root_user):
                    root_user = [int(item) for item in root_user]
            except Exception as e:
                print(f"Error processing root file CSV: {e}")
                root_user = None
        else: 
            # Set root user if not provided
            if str(root_user).lower() != 'none': 
                root_user = [i.strip() for i in root_user.split(',')]
            elif not root_user or str(root_user).lower() == 'none':
                # Random the gene if None
                gene = random.choice(adata.var_names.tolist())
                print(f"DEBUG: Selected random gene: '{gene}'")
                print(f"DEBUG: Gene type: {type(gene)}")
                print(f"DEBUG: Gene in var_names? {gene in adata.var_names}")
                root_user = [adata[:, gene].X.argmax()]
        
        # INITIALIZE PARAMETERS
        n_pcs = 50
        ncomp = 50 
        random_seed = 0 
        small_pop = 2 
        too_big_factor = 0.3 
        memory = 50
        random_seed = 0

        if time_series: 
            time_series_labels=time_series_labels
        else:
            time_series_labels=None

        velocity_matrix = None
        gene_matrix = adata.X.todense() if hasattr(adata.X, 'todense') else adata.X
        velo_weight = 0

        if use_velocity and velocity_matrix_file is not None:
            try:
                velocity_df = velocity_matrix_file
                
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
                velocity_matrix = velocity_df.values
                gene_matrix = adata.X.toarray() if hasattr(adata.X, 'toarray') else adata.X
                
                velo_weight = 0.5
                
                print(f"✓ Velocity loaded: {len(common_cells)} cells, {len(common_genes)} genes")
                
            except Exception as e:
                print(f"✗ Velocity failed: {e}")
                velocity_matrix = None
                velo_weight = 0

        if do_spatial:
            
            # Add text input?
            if spatial_coords_file:
                coords = pd.read_csv(spatial_coords_file) 
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
                true_label = cytometry_file_phase
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
                import traceback
                traceback.print_exc()
                knn = 20
                random_seed = 1
                root_user = None
                true_label = None
                raise 

        if 'PARC' in adata.obs.columns: 
            embedding = adata.obs['PARC']
            true_label = adata.obs['annotations']
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
        results['via_obj'] = v0

        results['adata'] = adata

        return results
    
    except Exception as e:
        return {'error': str(e)}
    
# Get embedding value for cytometry
def via_analysis_embedding(params, file_data=None):
    print("Calculating embedding")
    data_categories = params.get('par_option', [])
    do_cytometry = 'cytometry' in data_categories
    if file_data is not None: 
        cytometry_file_features = file_data.get('cytometry-features-upload')

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