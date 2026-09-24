from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse

from pathlib import Path
import uuid, zipfile, base64
from zipfile import ZipFile
from io import BytesIO

import scanpy as sc 
import numpy as np 
import pandas as pd 
import scipy 
import plotly.express as px
from sklearn.manifold import TSNE
from umap import UMAP 
from anndata import AnnData
from typing import Dict 
from pydantic import BaseModel

# Refer to the other files in backend 
from params import JobConfig, PreprocessChoice, PARCParams, PreviewParams, VIAParams
from via_analysis import run_via_analysis, via_analysis_embedding
from plotting import via_plot, more_plot

app = FastAPI(title="StaVia 0.0.2")

app.add_middleware( 
    CORSMiddleware,
    allow_origins=["*"], 
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = Path("./storage/raw_uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# ----- Job Management -------
jobs: dict[str, JobConfig] = {}

def create_job():
    job = JobConfig()
    job.id = str(uuid.uuid4())

    # TODO SEND PARAMETERS 
    jobs[job.id] = {
        "name": job.name, 
        "job": job
    }

    return {
        "jobId": job.id, 
        "adata": None,
        "job": job 
    }

def get_job(jobId: str):
    if jobId not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    return jobs[jobId]

def get_job_adata(job: JobConfig) -> AnnData:
    path = job.processed_h5ad_path or job.h5ad_path
    if not path or not Path(path).exists():
        raise HTTPException(status_code=400, detail="Processed AnnData file not found")
    return sc.read_h5ad(path)

def write_adata(jobId: str, adata: AnnData):
    job_data = get_job(jobId)
    job: JobConfig = job_data["job"]
    processed_dir = Path(f"storage/jobs/{jobId}")
    processed_dir.mkdir(parents=True, exist_ok=True)
    processed_path = processed_dir / "processed.h5ad"
    adata.write_h5ad(processed_path)
    job.processed_h5ad_path = str(processed_path)

@app.get("/loadJob/{jobId}")
async def load_job(jobId: str):
    jobs.get(jobId)

    # TODO LOAD PARAMS 
    return {
        "jobId": jobId,
        "name": jobs["name"],
    }

@app.post("/rename/{jobId}")
async def rename_job(jobId: str, new_name: str):
    if jobId not in jobs: 
        raise HTTPException(status_code=404, detail="Job not found")

    jobs[jobId]["name"] = new_name
    return {"status": "success", "jobId": jobId, "name": new_name}

@app.delete("/job/{jobId}")
def resetJob(jobId: str):
    jobs.pop(jobId, None)
    return {"reset": True}

# ----- Upload Endpoint -------
@app.post("/upload")
def upload_file(file: UploadFile = File(...)):
    """ 
    Processes the uploaded files (in zip file)
    1. H5AD files
    2. 10X Genomics files: matrix.mtx, features.tsv, barcodes.tsv
    3. Other .csv and .tsv files 
    4. Annotation files
    """
    job = create_job()
    job = job["job"]
    jobId = job.id

    if not file.filename.endswith(".zip"):
        raise HTTPException(status_code=400, detail="Only .zip files are allowed.")

    temp_dir = Path(f"uploads/temp_{jobId}")
    temp_dir.mkdir(parents=True, exist_ok=True)

    zip_bytes = file.file.read()
    with ZipFile(BytesIO(zip_bytes), "r") as filezip:
        for member in filezip.infolist():
            if member.is_dir():
                continue

            filename = Path(member.filename).name

            if filename.startswith(".") or not filename: 
                continue 

            target_file_path = temp_dir / filename
            with filezip.open(member) as source, open(target_file_path, "wb") as target: 
                target.write(source.read())

    all_extracted_paths = [str(p) for p in temp_dir.rglob("*")]

    adata = None
    # ----- Process H5AD ------
    h5ad_files = [p for p in all_extracted_paths if p.endswith(".h5ad")]
    if h5ad_files:
        adata = sc.read_h5ad(h5ad_files[0])
        job.h5ad_path = h5ad_files[0]

    # ----- Process 10X ------
    mtx_files = [p for p in temp_dir.rglob("*") if p.name in ("matrix.mtx", "matrix.mtx.gz")]
    if mtx_files:
        target_dir = mtx_files[0].parent
        adata = sc.read_10x_mtx(str(target_dir), var_names='gene_symbols')
        job.tenX_path = str(temp_dir)

    # We write to disk instead of storing it here 
    write_adata(jobId, adata)

    # ----- Check Analyses -------
    files = [p.name for p in temp_dir.rglob("*") if p.is_file()]
    analyses = []

    for filename in files: 
        name_lower = filename.lower()
        file_path = temp_dir / filename

        # TODO It's better to store these directly in adata rather than in jobs because of the file size. Should keep job lightweight 
        if 'time_series' in name_lower and filename.endswith(('.csv', '.tsv')):
            job.metadata['time_series'] = pd.read_csv(file_path)

        if 'annotation' in name_lower and filename.endswith(('.csv', '.tsv')):
            job.metadata['annotation'] = pd.read_csv(file_path)

        if 'spatial' in name_lower and filename.endswith(('.csv', '.tsv')):
            job.metadata['spatial'] = pd.read_csv(file_path)

        if 'root' in name_lower and filename.endswith(('.csv', '.tsv')):
            job.metadata['root'] = pd.read_csv(file_path)

        # TODO READ LOOM AND H5AD 
        if 'velocity' in name_lower and filename.endswith(('.csv', '.loom', '.h5ad')):
            job.metadata['velocity'] = pd.read_csv(file_path)

        if 'cytometry_features' in name_lower and filename.endswith(('.csv', '.tsv')):
            job.metadata['cytometry_features'] = pd.read_csv(file_path)

        if 'cytometry_phase' in name_lower and filename.endswith(('.csv', '.tsv')):
            job.metadata['cytometry_phase'] = pd.read_csv(file_path)

    analyses = list({
        'time_series' if 'time_series' in f.lower() else
        'spatial' if 'spatial' in f.lower() or 'coord' in f.lower() else
        'velocity' if 'velocity' in f.lower() else
        'cytometry' if 'cytometry' in f.lower() else None
        for f in files
    } - {None})

    preview_data = {
        "adata_info": {
            'dimensions': f"{adata.n_obs} cells × {adata.n_vars} genes",
            'obs_keys': list(adata.obs.keys()),
            'var_keys': list(adata.var.keys()),
            'layers': list(adata.layers.keys()),
            'uns_keys': list(adata.uns.keys()),
            'obsm_keys': list(adata.obsm.keys()),
            'varm_keys': list(adata.varm.keys())
        },
        "job_id": jobId, 
        "analyses": analyses,
        "files": files[:20]
    }

    return JSONResponse(preview_data)

# ----- Preprocessing Stage ----------
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

@app.post("/preprocess/{jobId}")
def preprocess_data(jobId: str, update: PreprocessChoice):
    job_data = get_job(jobId)
    job = job_data["job"]
    preprocess_choice = update.preprocessChoice
    order = update.order 

    # We do this in case the user wants to preprocess again; better than storing an extra adata 
    adata = sc.read_h5ad(job.h5ad_path) if job.h5ad_path is not None else sc.read_10x_mtx(job.tenX_path, var_names='gene_symbols')
    if adata is None: 
        raise HTTPException(status_code=400, detail="AnnData object not found")

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
        else:
            print(f"Warning: Step {i} not found, skipping")

    write_adata(jobId, adata)

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

# ------- Preview Data Stage ----------
# TODO Maybe create another GET endpoint for plot streaming 
@app.post("/preview/{jobId}")
def preview_data(jobId: str, update: PreviewParams):
    job_data = get_job(jobId)
    job = job_data["job"]
    adata = get_job_adata(job)
    
    X = adata.X.toarray() if scipy.sparse.issparse(adata.X) else adata.X
    X = np.asarray(X, dtype=np.float32)

    plots = {}
    em = update.em
    em_list = [x.strip() for x in em.split(',')]
    color_data = adata.obs[update.colorUmap] if (update.colorUmap and update.colorUmap in adata.obs) else None

    if 'X_pca' not in adata.obsm:
        sc.pp.pca(adata, n_comps=50)
    X_pca = adata.obsm['X_pca']

    # TODO Check why there is only one color on the plot (should have multiple colors)
    if 'pca' in em_list:
        fig_pca = px.scatter(x=X_pca[:, 0], y=X_pca[:, 1], color=color_data)
        plots["pca"] = fig_pca.to_html(include_plotlyjs="cdn", full_html=True)
    if 'umap' in em_list: 
        umap = UMAP(n_components=update.nComps, n_neighbors=update.nNeighbors, min_dist=update.minDist, spread=update.spread)
        projection_2d = umap.fit_transform(X_pca)
        fig_umap = px.scatter(x=projection_2d[:, 0], y=projection_2d[:, 1], color=color_data, labels={"color":f"{update.colorUmap}"})
        plots["umap"] = fig_umap.to_html(include_plotlyjs="cdn", full_html=True)
    # TODO Change PHATE TO T-SNE (easier implementation and equally important)
    if 'phate' in em_list: 
        tsne = TSNE(n_components=2, random_state=0)
        projections = tsne.fit_transform(X_pca)
        fig_tsne = px.scatter(x=projections[:, 0], y=projections[:, 1], color=color_data, labels={"color":f"{update.colorUmap}"})
        plots["tsne"] = fig_tsne.to_html(include_plotlyjs="cdn", full_html=True)

    return JSONResponse(content=plots)

# TODO Do PARC embedding 

# ----- Analysis and Plot Generation Stage --------
@app.post("/analyze/{jobId}")
def analyze(jobId: str, update: VIAParams):
    job_data = get_job(jobId)
    job = job_data["job"]
    adata = get_job_adata(job)
    
    results = run_via_analysis(adata=adata, params=update, file_data=job)
    embedding = via_analysis_embedding(params=update, file_data=job)

    v0 = results.get("via_obj")
    adata = results.get("adata")
    
    plots = via_plot(params=update, v0=v0, file_data=job, adata=adata, embedding=embedding)
    
    return JSONResponse({
        'success': True,
        'plots': plots
    })

# ----- Download Plots --------
# TODO omit Plotly plots because the user can already download them directly 

class DownloadRequest(BaseModel):
    plot_data: Dict[str, str]

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

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn 

    uvicorn.run(app, host="127.0.0.1", port=8000)
    # python main.py --start-server
    # check API calls at: 
    # http://localhost:8000/docs