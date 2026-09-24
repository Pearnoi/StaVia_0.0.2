from pydantic import BaseModel, Field
from typing import Optional, List

class PreprocessChoice(BaseModel):
    preprocessChoice: str = "default"
    order: str= "12345"

class PARCParams(BaseModel):
    nNeighbors: int = 10 
    nPcs: int = 40 
    jacStdGlobal: float = 0.15 
    randomSeed: int = 1
    smallPop: int = 50 

class PreviewParams(BaseModel):
    em: Optional[str] = None 
    colorUmap: Optional[str] = None
    colorScheme: str = "viridis"
    nNeighbors: int = 15.0
    nComps: int = 2
    minDist: float = 0.1
    spread: float = 1.0

class VIAParams(BaseModel):
    knn: int = 30
    clusterGraphPruning: float = 0.9
    edgeBundlePruning: float = 0.9
    edgePruningClusteringResolution: float = 1.0 
    dpi: int = 150
    varNames: Optional[list] = None
    obs: Optional[str] = None
    parOption: List[str] = Field(default_factory=list)

class JobConfig(BaseModel):
    name: str = "Untitled Job"
    id: str = "jobId"
    h5ad_path: Optional[str] = None 
    processed_h5ad_path: Optional[str] = None 
    tenX_path: Optional[str] = None 
    metadata:dict = Field(default_factory=dict)
    parcParams: PARCParams = Field(default_factory=PARCParams)
    umapParams: PreviewParams = Field(default_factory=PreviewParams)
    viaParams: VIAParams = Field(default_factory=VIAParams)