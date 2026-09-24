from fastapi import FastAPI, UploadFile, File, BackgroundTasks, Request, HTTPException, Form
from fastapi.concurrency import run_in_threadpool
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from redis import asyncio as aioredis
from typing import Dict, Any, Optional, List
import asyncio

from fastapi.responses import JSONResponse, StreamingResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware

from fastapi_cache import FastAPICache
from fastapi_cache.backends.redis import RedisBackend
from fastapi_cache.decorator import cache
from fastapi_cache.key_builder import default_key_builder

import pandas as pd
import scanpy as sc
import base64, shutil, umap, gc, scipy, uuid, gzip, parc, phate, loompy, zipfile
from io import BytesIO
import matplotlib.pyplot as plt
import numpy as np 
from functools import wraps
import anndata as ad
from scipy import sparse
import aiofiles, io
from io import StringIO
from pathlib import Path
from pydantic import BaseModel

from via_analysis import run_via_analysis, via_analysis_embedding
from plotting import via_plot, more_plot

@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    """ Initialize cache and set global configuration """
    try:
        redis = await aioredis.from_url("redis://localhost")
        FastAPICache.init(RedisBackend(redis), prefix="fastapi-cache")
    except Exception as e:
        print(f"⚠️ Redis not available: {e}") # FastAPICache will be disabled but the app still works
    yield

class DownloadRequest(BaseModel):
    plot_data: Dict[str, str]

class MemoryCache:
    """Simple in-memory cache"""
    def __init__(self, name: str):
        self.name = name
        self.cache = {}
    
    def clear(self):
        self.cache.clear()
        print(f"{self.name} cache cleared")
    
    def set(self, key: str, value: Any):
        self.cache[key] = value
    
    def get(self, key: str):
        return self.cache.get(key)
    
    def delete(self, key: str):
        if key in self.cache:
            del self.cache[key]

# Initialize caches 
preprocess_cache = MemoryCache("Preprocess")
via_cache = MemoryCache("VIA")
initial_adata_cache = MemoryCache("InitialAnndata")
annotation_cache = MemoryCache("Annotation")
file_cache = MemoryCache("Files")

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

app = FastAPI(lifespan = lifespan)

# For Flutter API 
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_methods=["*"],
    allow_headers=["*"],
)


# TODO Write an SQL database --> delete and add functions, maybe change the mechanism a bit to save everything (like results)

# Store processing jobs
processing_jobs: Dict[str, Dict] = {}
# Store results for completed jobs
job_results: Dict[str, Dict] = {}

@app.get("/status/{job_id}")
async def get_status(job_id: str):
    """Check processing status and return results when complete"""
    job = processing_jobs.get(job_id, {"status": "not_found"})
    
    # If job is completed, return the full data including adata_info
    if job.get("status") == "completed":
        return JSONResponse(content={
            "status": "completed",
            "progress": 100,
            "adata_info": job.get("adata_info"),
            "analyses": job.get("analyses", []),
            "main_data": job.get("main_data"),
            "files": job.get("files", [])
        })
    elif job.get("status") == "failed":
        return JSONResponse(content={
            "status": "failed",
            "error": job.get("error", "Unknown error")
        })
    else:
        return JSONResponse(content={
            "status": job.get("status", "processing"),
            "progress": job.get("progress", 0)
        })
    
#### FILE UPLOAD STAGE ####

@app.post("/upload")
async def upload(request: Request, background_tasks: BackgroundTasks, file: UploadFile = File(...)):
    """ Calls Zip File Processing """
    unique_id = str(uuid.uuid4())[:8]

    # Clear cache first
    preprocess_cache.clear()  
    via_cache.clear() 
    initial_adata_cache.clear()

    # Read file content once
    zip_content = await file.read()

    try:
        # Process the zip file (synchronously within the request)
        result = await process_zip(zip_content, unique_id, file.filename)
        
        if result.get("error"):
            return JSONResponse(content={"error": result["error"]}, status_code=400)
        
        # Return the same structure as Flask version
        return JSONResponse(content={
            "success": True,
            "job_id": unique_id, 
            "message": "ZIP file processed successfully",
            "adata_info": result.get("adata_info"),
            "analyses": result.get("analyses", []),
            "main_data": result.get("main_data"),
            "files": result.get("files", [])
        })
        
    except Exception as e:
        print(f"❌ Upload failed: {str(e)}")
        return JSONResponse(content={"error": str(e)}, status_code=500)

async def process_zip(zip_content: bytes, job_id: str, filename: str):
    """ Processes the uploaded files (in zip file)
        1. H5AD files
        2. 10X Genomics files: matrix.mtx, features.tsv, barcodes.tsv
        3. Other .csv and .tsv files 
        4. Annotation files
    """
    print(f"🔵 [JOB {job_id}] Starting process_zip for {filename}")
    try:
        print(f"🔵 [JOB {job_id}] Setting status to extracting...")
        processing_jobs[job_id] = {"status": "extracting", "progress": 10}

        def extract_zip():
            with zipfile.ZipFile(io.BytesIO(zip_content)) as zip_handle:
                file_list = zip_handle.namelist() 
                
                # Find files
                h5ad_files = [f for f in file_list if f.endswith(".h5ad")]
                tenx_extensions = ['.mtx', '.mtx.gz', '.tsv', '.tsv.gz', '.csv']
                tenx_files = [f for f in file_list if any(f.endswith(ext) for ext in tenx_extensions)]
                csv_files = [f for f in file_list if f.endswith(('.csv', '.tsv'))]
                annotation_files = [f for f in file_list if 'annotation' in f.lower() or 'true_label' in f.lower()]

                print(f"🟡 [JOB {job_id}] Found - H5AD: {len(h5ad_files)}, 10X: {len(tenx_files)}, CSV: {len(csv_files)}")

                result = {
                    'file_list': file_list,
                    'h5ad_files': h5ad_files,
                    'tenx_files': tenx_files,
                    'csv_files': csv_files,
                    'annotation_files': annotation_files,
                    'detected_analyses': []
                }

                # Extract files based on types 
                if h5ad_files:
                    result['type'] = 'h5ad'
                    result['data'] = zip_handle.read(h5ad_files[0])
                    result['main_filename'] = h5ad_files[0]
                    print(f"🟡 [JOB {job_id}] Detected H5AD file: {h5ad_files[0]}")
                
                elif tenx_files:
                    result['type'] = '10x'
                    tenx_data = {}
                    for tf in tenx_files:
                        tenx_data[tf] = zip_handle.read(tf)
                    result['data'] = tenx_data
                    print(f"🟡 [JOB {job_id}] Detected 10X with {len(tenx_files)} files")
                
                elif csv_files:
                    result['type'] = 'csv'
                    result['data'] = zip_handle.read(csv_files[0])
                    result['main_filename'] = csv_files[0]
                    print(f"🟡 [JOB {job_id}] Detected CSV file: {csv_files[0]}")
                
                else:
                    result['type'] = 'unknown'
                    result['data'] = None
                    print(f"🟡 [JOB {job_id}] No valid data files found!")
                
                if annotation_files:
                    result['annotation_data'] = zip_handle.read(annotation_files[0])
                    result['annotation_filename'] = annotation_files[0]
                    print(f"🟡 [JOB {job_id}] Found annotation file: {annotation_files[0]}")
                
                return result
        
        result = await asyncio.to_thread(extract_zip)
        adata = None

        # =============================================
        # 1. PROCESS MAIN DATA FILE (H5AD, 10X, CSV)
        # =============================================
        if result["type"] == "h5ad":
            print(f"🔵 [JOB {job_id}] Processing H5AD file...")
            h5ad_path = Path(f"uploads/{job_id}.h5ad")
            h5ad_path.parent.mkdir(exist_ok=True)

            async with aiofiles.open(h5ad_path, "wb") as f:
                await f.write(result["data"])
            
            def load_h5ad():
                return sc.read_h5ad(h5ad_path)
            
            adata = await run_in_threadpool(load_h5ad)
            print(f"✓ Loaded H5AD: {adata.n_obs} cells × {adata.n_vars} genes")

        elif result["type"] == "10x":
            print(f"🔵 [JOB {job_id}] Processing 10X files...")
            temp_dir = Path(f"uploads/temp_{job_id}")
            temp_dir.mkdir(parents=True, exist_ok=True) 
        
            for filepath, content in result['data'].items():
                filename = Path(filepath).name
                full_path = temp_dir / filename
                
                if filename.endswith('.gz'):
                    async with aiofiles.open(full_path, 'wb') as f:
                        await f.write(content)
                else:
                    async with aiofiles.open(full_path, 'wb') as f:
                        await f.write(content)
                
                print(f"🔵 Extracted: {filename}")

            extracted = list(temp_dir.iterdir())
            print(f"🔵 Extracted files: {[f.name for f in extracted]}")
            
            has_matrix = any('matrix' in f.name.lower() for f in extracted)
            has_features = any('feature' in f.name.lower() or 'gene' in f.name.lower() for f in extracted)
            has_barcodes = any('barcode' in f.name.lower() for f in extracted)
            
            if not (has_matrix and has_features and has_barcodes):
                raise ValueError(f"Missing 10X files - Matrix: {has_matrix}, Features: {has_features}, Barcodes: {has_barcodes}")

            print(f"🔵 [JOB {job_id}] Loading 10X data...")
            def load_10x():
                return sc.read_10x_mtx(str(temp_dir), var_names='gene_symbols')
        
            adata = await run_in_threadpool(load_10x)
            print(f"✓ Loaded 10X: {adata.n_obs} cells × {adata.n_vars} genes")
            
            shutil.rmtree(temp_dir)

        elif result['type'] == 'csv':
            def load_csv():
                csv_content = result['data'].decode('utf-8')
                from io import StringIO
                df = pd.read_csv(StringIO(csv_content))
                
                numeric_cols = df.select_dtypes(include=[np.number]).columns
                adata_temp = ad.AnnData(X=df[numeric_cols].values)
                adata_temp.var_names = numeric_cols.tolist()
                adata_temp.obs_names = df.index.astype(str).tolist()
                return adata_temp
            
            adata = await run_in_threadpool(load_csv)
            print(f"✓ Loaded CSV: {adata.n_obs} cells × {adata.n_vars} genes")

        else:
            processing_jobs[job_id] = {"status": "failed", "error": "No valid data files found"}
            return

        # =============================================
        # 2. STORE MAIN ADATA IN CACHE
        # =============================================
        initial_adata_cache.set(job_id, adata)

        # =============================================
        # 3. PROCESS AND STORE FILE DATA IN file_cache
        # =============================================
        file_data = {}
        file_list = result.get('file_list', [])
        
        # Go through all files in the zip
        for filename in file_list:
            name_lower = filename.lower()
            
            # Time series labels
            if 'time_series' in name_lower and filename.endswith(('.csv', '.tsv')):
                try:
                    content = result.get('data') if result.get('main_filename') == filename else None
                    if content:
                        df = pd.read_csv(StringIO(content.decode('utf-8')))
                        file_data['time_series'] = df
                        print(f"✅ Stored time series from: {filename}")
                except Exception as e:
                    print(f"⚠️ Could not load time series {filename}: {e}")
            
            # True labels / annotations
            elif 'true_label' in name_lower or ('annotation' in name_lower and 'true' not in name_lower):
                try:
                    if result.get('annotation_data'):
                        content = result.get('annotation_data')
                        df = pd.read_csv(StringIO(content.decode('utf-8')))
                        file_data['annotation'] = df
                        print(f"✅ Stored annotation from: {filename}")
                except Exception as e:
                    print(f"⚠️ Could not load annotation {filename}: {e}")
            
            # Spatial coordinates
            elif ('spatial' in name_lower or 'coord' in name_lower) and filename.endswith(('.csv', '.tsv')):
                try:
                    content = zipfile.read(filename) 
                    df = pd.read_csv(StringIO(content.decode('utf-8')))
                    file_data['spatial'] = df
                    print(f"✅ Stored spatial coordinates from: {filename}")
                except Exception as e:
                    print(f"⚠️ Could not load spatial coordinates {filename}: {e}")
            
            # Root cell selection
            elif 'root' in name_lower and filename.endswith(('.csv', '.tsv')):
                try:
                    content = zipfile.read(filename)
                    df = pd.read_csv(StringIO(content.decode('utf-8')))
                    file_data['root'] = df
                    print(f"✅ Stored root cells from: {filename}")
                except Exception as e:
                    print(f"⚠️ Could not load root cells {filename}: {e}")
            
            # Velocity matrix
            elif 'velocity' in name_lower and filename.endswith(('.loom', '.csv', '.h5ad')):
                try:
                    content = zipfile.read(filename)
                    # Store raw bytes with file type info
                    file_data['velocity_raw'] = {
                        'filename': Path(filename).name,
                        'content': content,
                        'type': 'loom' if filename.endswith('.loom') else 'h5ad'
                    }
                    print(f"✅ Stored raw velocity file: {filename}")
                except Exception as e:
                    print(f"⚠️ Could not load velocity matrix {filename}: {e}")
            
            # Gene matrix
            elif 'gene_matrix' in name_lower and filename.endswith('.csv'):
                try:
                    content = zipfile.read(filename)
                    df = pd.read_csv(StringIO(content.decode('utf-8')))
                    file_data['gene_matrix'] = df
                    print(f"✅ Stored gene matrix from: {filename}")
                except Exception as e:
                    print(f"⚠️ Could not load gene matrix {filename}: {e}")
            
            # Cytometry feature matrix
            elif 'cytometry_feature' in name_lower or 'cyto_feature' in name_lower:
                try:
                    content = zipfile.read(filename)
                    df = pd.read_csv(StringIO(content.decode('utf-8')))
                    file_data['cytometry_features'] = df
                    print(f"✅ Stored cytometry features from: {filename}")
                except Exception as e:
                    print(f"⚠️ Could not load cytometry features {filename}: {e}")
            
            # Cytometry phase matrix
            elif 'cytometry_phase' in name_lower or 'cyto_phase' in name_lower:
                try:
                    content = zipfile.read(filename)
                    df = pd.read_csv(StringIO(content.decode('utf-8')))
                    file_data['cytometry_phase'] = df
                    print(f"✅ Stored cytometry phase from: {filename}")
                except Exception as e:
                    print(f"⚠️ Could not load cytometry phase {filename}: {e}")
        
        # Store all file data in cache
        if file_data:
            file_cache.set(job_id, file_data)
            print(f"✅ Stored {len(file_data)} file types in file_cache for job {job_id}")

        # 4. DETECT ANALYSIS TYPES
        analyses = []
        for f in file_list:
            f_lower = f.lower()
            if 'time_series' in f_lower:
                analyses.append('time_series')
            elif 'spatial' in f_lower or 'coord' in f_lower:
                analyses.append('spatial')
            elif 'velocity' in f_lower:
                analyses.append('velocity')
            elif 'cytometry' in f_lower:
                analyses.append('cytometry')

        analyses = list(set(analyses))

        if result['type'] == 'h5ad':
            main_data_display = 'H5AD'
        elif result['type'] == '10x':
            main_data_display = '10X'
        elif result['type'] == 'csv':
            main_data_display = 'CSV'
        else:
            main_data_display = 'Unknown'

        # 5. RETURN RESULTS
        return_data = {
            "adata_info": {
                'dimensions': f"{adata.n_obs} cells × {adata.n_vars} genes",
                'obs_keys': list(adata.obs.keys()),
                'var_keys': list(adata.var.keys()),
                'layers': list(adata.layers.keys()),
                'uns_keys': list(adata.uns.keys()),
                'obsm_keys': list(adata.obsm.keys()),
                'varm_keys': list(adata.varm.keys())
            },
            "analyses": analyses,
            "main_data": {'display': main_data_display},
            "files": file_list[:20]
        }

        processing_jobs[job_id] = {
            "status": "completed",
            "progress": 100,
            "adata_info": return_data["adata_info"],
            "analyses": return_data["analyses"],
            "main_data": return_data["main_data"],
            "files": return_data["files"]
        }
        
        print(f"✅ Job {job_id} completed successfully")
        return return_data
        
    except Exception as e:
        print(f"❌ Job {job_id} failed: {str(e)}")
        processing_jobs[job_id] = {"status": "failed", "error": str(e)}
        raise

#### PREPROCESSING STAGE ####

def cell_filtering(adata, min_genes=100):
    """ Filter out cells that express lower genes than the threshold """
    sc.pp.filter_cells(adata, min_genes)
    print("Pass cell filtering")

def gene_filtering(adata, min_cells=10):
    """ Filter out genes that are expressed by cells (no. lower than the threshold) """
    sc.pp.filter_genes(adata, min_cells)
    print("Pass gene filtering")

def data_normalization(adata):
    """ Just normalize data """
    sc.pp.normalize_total(adata)
    print("Pass data normalization")

def log_normalization(adata):
    """ Normalize to be > 0 """
    sc.pp.log1p(adata)
    print("Pass log normalization")

def pca_computation(adata, n_comps=100):
    """ Compute Principal Components for UMAP and other embeddings """
    sc.pp.pca(adata, n_comps)
    print("Pass PCA")

@app.post('/preprocess')
async def preprocess_data(request: Request):
    print("\n=== CACHE CHECK ===")
    form_data = await request.form()
    preprocess_choice = form_data.get('preprocessing_choice')
    order = form_data.get('preprocessing_order', '12345')

    job_id = form_data.get('job_id')
    
    if not job_id:
        return JSONResponse(content={"error": "No data found. Please upload a file first."}, status_code=400)
    
    adata = initial_adata_cache.get(job_id)
    if adata is None:
        return JSONResponse(content={"error": "No data found in cache. Please upload a file first."}, status_code=400)
    
    if scipy.sparse.issparse(adata.X) and (adata.n_obs * adata.n_vars < 1e7):
            adata.X = adata.X.toarray()

    print('Preprocessing Data')
    steps = {
        '1': lambda: cell_filtering(adata, 100),
        '2': lambda: gene_filtering(adata, 10),
        '3': lambda: data_normalization(adata),
        '4': lambda: log_normalization(adata),
        '5': lambda: pca_computation(adata, 100)
    }

    if preprocess_choice == 'default':
        order = '12345'

    for i in order:
        if i in steps: 
            steps[i]()
            processing_jobs[job_id]["progress"] = 20 + (int(i) * 10)
        else:
            print(f"Warning: Step {i} not found, skipping")

    preprocess_cache.set(job_id, adata)
    print('Cached preprocessed data')

    preview_data = {
        'adata_info': {
            'dimensions': f"{adata.n_obs} cells × {adata.n_vars} genes",
            'obs_keys': list(adata.obs.keys()),
            'var_keys': list(adata.var.keys()),
            'layers': list(adata.layers.keys()),
            'uns_keys': list(adata.uns.keys()),
            'obsm_keys': list(adata.obsm.keys()),
            'varm_keys': list(adata.varm.keys())
        }
    }
    
    return JSONResponse(preview_data)

@app.post('/preview')
async def preview(
    request: Request,
    em: str = Form(...),
    color_umap: str = Form('parc_cluster'),
    color_scheme: str = Form('viridis'),
    n_neighbors: float = Form(15),
    n_components: int = Form(2),
    min_dist: float = Form(0.1),
    spread: float = Form(1.0)
    ):
    
    print(f"🔵 Preview endpoint called with em={em}, color_umap={color_umap}, color_scheme={color_scheme}")
    form_data = await request.form()
    print(f"🔵 Form data: {form_data}")
    
    job_id = form_data.get('job_id')
    print(f"🔵 Job ID: {job_id}")
    if not job_id:
        return JSONResponse(content={"error": "No data found. Please upload a file first."}, status_code=400)
   
    adata = None
    data_source = None
    
    preprocessed_adata = preprocess_cache.get(job_id)
    if preprocessed_adata is not None:
        adata = preprocessed_adata
        data_source = 'preprocessed'
        print(f"✓ Using preprocessed data from preprocess_cache for job {job_id}")

    if adata is None:
        initial_adata = initial_adata_cache.get(job_id)
        if initial_adata is not None:
            adata = initial_adata
            data_source = 'initial'
            print(f"✓ Using initial uploaded data from initial_adata_cache for job {job_id}")

    if adata is None:
        return JSONResponse(content={"error": "No data found in cache. Please upload files first."}, status_code=400)
    
    print(f"✅ Adata loaded: {adata.n_obs} cells, {adata.n_vars} genes")

    valid = ['viridis', 'rainbow', 'paired', 'plasma', 'inferno']
    if color_scheme not in valid:
        color_scheme = 'viridis'

    pca_plot = umap_plot = phate_plot = None
    em_list = [x.strip() for x in em.split(',')]

    if 'pca' in em_list:
        fig, ax = plt.subplots(figsize=(10, 8))
        sc.pl.pca_variance_ratio(adata, log=False, n_pcs=50, show=False)
        pca_img = BytesIO()
        plt.savefig(pca_img, format='png', bbox_inches='tight', dpi=120)
        plt.close()
        pca_plot = "data:image/png;base64," + base64.b64encode(pca_img.getvalue()).decode('utf-8')

    if 'umap' in em_list:
        # fig, ax = plt.subplots(figsize=(10, 8))
        # adata.obsm['X_umap'] = umap.UMAP(n_neighbors=int(n_neighbors), min_dist=float(min_dist), spread=float(spread), n_components=int(n_components), init='pca').fit_transform(adata.obsm['X_pca'])
        # sc.pl.embedding(adata, basis='X_umap', color=[color_umap], palette=color_scheme, size=200, show=False, return_fig=True)
        # umap_img = BytesIO()
        # plt.savefig(umap_img, format='png', bbox_inches='tight', dpi=120)
        # plt.close()
        # umap_plot = "data:image/png;base64," + base64.b64encode(umap_img.getvalue()).decode('utf-8')
        adata.obsm['X_umap'] = umap.UMAP(n_neighbors=int(n_neighbors), min_dist=float(min_dist), spread=float(spread), n_components=int(n_components), init='pca').fit_transform(adata.obsm['X_pca'])
        fig = ipl.scatter(adata, basis=['umap'], obs_keys=[color_umap], subsample='density', keep_frac=0.5)
        string_io = io.StringIO()
        fig.save(string_io, embed=False)
        html_content = string_io.getvalue()

    # if 'phate' in em_list: 
    #     phate_op = phate.PHATE(n_components=2, random_state=42)
    #     X_phate = phate_op.fit_transform(adata.X.T)
    #     adata.obsm['X_phate'] = X_phate

    #     plt.figure(figsize=(10, 8))
    #     sc.pl.umap(adata, color='PHATE')
    #     phate_img = BytesIO()
    #     plt.savefig(phate_img, format='png', bbox_inches='tight', dpi=120)
    #     plt.close('all')
    #     phate_plot = "data:image/png;base64," + base64.b64encode(phate_img.getvalue()).decode('utf-8')
    
    if data_source == 'preprocessed':
        preprocess_cache.set(job_id, adata)
    else:
        initial_adata_cache.set(job_id, adata)

    return JSONResponse({
                'success': True,
                'html': html_content,  # Send raw HTML
                'plot_type': 'interactive_umap'
            })

    # return JSONResponse({
    #     'plots': {
    #         'pca': pca_plot,
    #         'umap': umap_plot,
    #         'phate': phate_plot
    #     }
    # })

@app.post('/run_parc')
async def run_parc(
    request: Request,
    job_id: str = Form(...),  
    n_neighbors: int = Form(10),
    n_pcs: int = Form(40),
    jac_std_global: float = Form(0.15),
    random_seed: int = Form(1),
    small_pop: int = Form(50)
):
    """ Run PARC embedding (optional), which can be used in VIA analysis """
    adata = None
    
    # Check preprocessed cache first
    preprocessed_adata = preprocess_cache.get(job_id)
    if preprocessed_adata is not None:
        adata = preprocessed_adata
        print(f"✓ Using preprocessed data from preprocess_cache for job {job_id}")
    
    if adata is None:
        initial_adata = initial_adata_cache.get(job_id)
        if initial_adata is not None:
            adata = initial_adata
            print(f"✓ Using initial uploaded data from initial_adata_cache for job {job_id}")

    if adata is None:
        return JSONResponse(
            content={"error": "No data found in cache. Please upload files first."}, 
            status_code=400
        )
    
    # Check if annotation exists
    annotation_data = annotation_cache.get(job_id)  # You'll need to create this cache
    if annotation_data is None:
        return JSONResponse(
            content={"error": "No annotation file found. Please upload an annotation file first."},
            status_code=400
        )
    
    # Compute PCA if not present
    if 'X_pca' not in adata.obsm:
        sc.pp.pca(adata, n_comps=100)
    
    try:
        # Process annotations
        annotations_list = []
        if annotation_data:
            if isinstance(annotation_data, bytes):
                content = annotation_data.decode('utf-8')
                first_line = content.split('\n')[0]
                if ',' in first_line:
                    sep = ','
                elif '\t' in first_line:
                    sep = '\t'
                else:
                    sep = None
                
                if sep:
                    df = pd.read_csv(io.StringIO(content), header=None, sep=sep)
                    annotations_list = df[0].tolist()
                else:
                    annotations_list = [line.strip() for line in content.split('\n') if line.strip()]
        
        # Add annotations to adata
        adata.obs['annotations'] = pd.Categorical(annotations_list)
        
        # Run PARC
        parc1 = parc.PARC(adata.obsm['X_pca'], true_label=annotations_list, jac_std_global=jac_std_global,
            random_seed=random_seed, small_pop=small_pop)
        parc1.run_PARC()
        adata.obs['PARC'] = pd.Categorical(parc1.labels)
        
        plt.figure(figsize=(10, 8))
        sc.settings.n_jobs=4
        sc.pp.neighbors(adata, n_neighbors=10, n_pcs=40)
        sc.pl.umap(adata, color='annotations')
        sc.pl.umap(adata, color='PARC')
        parc_img = BytesIO()
        plt.savefig(parc_img, format='png', bbox_inches='tight', dpi=120)
        plt.close('all')
        parc_plot = "data:image/png;base64," + base64.b64encode(parc_img.getvalue()).decode('utf-8')
        
        return JSONResponse({
            'plots': {
                'parc': parc_plot
            }
        })
        
    except Exception as e:
        print(f"❌ PARC failed: {e}")
        return JSONResponse(
            content={"error": f"PARC analysis failed: {str(e)}"},
            status_code=500
        )

@app.post('/analyze')
async def analyze(
    request: Request,
    job_id: str = Form(...),
    var_names: Optional[str] = Form(None),
    knn: int = Form(30),
    cluster_graph_pruning: float = Form(0.9),
    edgebundle_pruning: float = Form(0.9),
    edgepruning_clustering_resolution: float = Form(1.0),
    dpi: int = Form(120),
    obs: Optional[str] = Form(None),
    par_option: List[str] = Form([])  
):
    """ Main Analysis Pipeline """
    try:
        print(f"🔵 Running VIA analysis for job: {job_id}")
        
        # Memory check
        try:
            import psutil
            if psutil.virtual_memory().available < 4 * 1024**3:  # <4GB
                gc.collect()
                if psutil.virtual_memory().available < 4 * 1024**3:
                    print("⚠️ Insufficient memory for analysis")
        except ImportError:
            pass
        
        # Get data from cache
        adata = None
        
        # Check preprocessed cache first
        preprocessed_adata = preprocess_cache.get(job_id)
        if preprocessed_adata is not None:
            adata = preprocessed_adata
            print(f"✓ Using preprocessed data from preprocess_cache for job {job_id}")
        
        # If not in preprocessed, check initial cache
        if adata is None:
            initial_adata = initial_adata_cache.get(job_id)
            if initial_adata is not None:
                adata = initial_adata
                print(f"✓ Using initial uploaded data from initial_adata_cache for job {job_id}")
        
        if adata is None:
            return JSONResponse(
                content={"error": "No data found in cache. Please upload files first."},
                status_code=400
            )
        
        # Collect file data from cache
        file_data = {}
        # Get stored file data from cache 
        cached_files = file_cache.get(job_id) or {}

        if 'time_series' in cached_files:
            file_data['time_series'] = cached_files['time_series']
        if 'annotation' in cached_files:
            file_data['annotation'] = cached_files['annotation']
        if 'spatial' in cached_files:
            file_data['spatial'] = cached_files['spatial']
        if 'root' in cached_files:
            file_data['root'] = cached_files['root']
        if 'velocity' in cached_files:
            file_data['velocity'] = cached_files['velocity']
        if 'gene_matrix' in cached_files:
            file_data['gene_matrix'] = cached_files['gene_matrix']
        if 'cytometry_features' in cached_files:
            file_data['cytometry_features'] = cached_files['cytometry_features']
        if 'cytometry_phase' in cached_files:
            file_data['cytometry_phase'] = cached_files['cytometry_phase']
        
        # Build params dictionary
        params = {
            'var_names': var_names,
            'knn': knn,
            'cluster_graph_pruning': cluster_graph_pruning,
            'edgebundle_pruning': edgebundle_pruning,
            'edgepruning_clustering_resolution': edgepruning_clustering_resolution,
            'dpi': dpi,
            'adata_obs': obs,
            'par_option': par_option if par_option else []
        }
        
        print(f"🔵 Params: {params}")
        
        # Run VIA analysis
        try:
            results = run_via_analysis(adata=adata, params=params, file_data=file_data)
            embedding = via_analysis_embedding(params=params, file_data=file_data)
            
            if 'error' in results:
                return JSONResponse(content=results, status_code=500)
            
            v0 = results['via_obj']
            adata = results['adata']
            
            # Cache VIA object
            via_cache.set(job_id, v0)
            
            # Generate plots
            plots = via_plot(params=params, v0=v0, file_data=file_data, adata=adata, embedding=embedding)
            
            return JSONResponse({
                'success': True,
                'plots': plots
            })
            
        except Exception as e:
            print(f"❌ VIA analysis failed: {e}")
            return JSONResponse(
                content={"error": str(e)},
                status_code=500
            )
            
    except Exception as e:
        print(f"❌ Analyze endpoint error: {e}")
        return JSONResponse(
            content={"error": str(e)},
            status_code=500
        )
    
@app.post("/download_all")
async def download_all(request: DownloadRequest):
    try:
        plot_data = request.plot_data
        mem_zip = BytesIO()
        
        with zipfile.ZipFile(mem_zip, mode='w') as zf:
            for plot_type, plot_b64 in plot_data.items():
                if plot_b64 and plot_b64.startswith('data:image/png;base64,'):
                    try:
                        img_data = base64.b64decode(plot_b64.split(',')[1])
                        zf.writestr(f"{plot_type}_plot.png", img_data)
                    except Exception as e:
                        print(f"Error processing {plot_type}: {str(e)}")
                        continue
        
        mem_zip.seek(0)
        
        return StreamingResponse(
            mem_zip,
            media_type="application/zip",
            headers={
                "Content-Disposition": "attachment; filename=all_plots.zip"
            }
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))