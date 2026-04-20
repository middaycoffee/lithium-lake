"""@bruin
name: ingestion.materials_bronze
type: python
description: "Fetch Li solid electrolyte candidates from Materials Project API and land in GCS bronze layer"
@bruin"""

import os
import pandas as pd
from mp_api.client import MPRester
from google.cloud import storage
from dotenv import load_dotenv

load_dotenv()

FIELDS = [
    "material_id",
    "formula_pretty",
    "elements",
    "energy_above_hull",
    "band_gap",
    "shear_modulus",
    "bulk_modulus",
    "symmetry",
    "last_updated",
]

with MPRester(os.getenv("MATERIALS_PROJECT_API")) as mpr:
    docs = mpr.materials.summary.search(
        elements=["Li"],
        energy_above_hull=[0, 0.05],
        band_gap=[2.0, 100],
        num_elements=(2, 4),
        fields=FIELDS
    )

df = pd.DataFrame([doc.model_dump() for doc in docs])
df = df.drop(columns=["fields_not_requested"], errors="ignore")

assert len(df) > 0, "No rows returned from API"
assert df["material_id"].notna().all(), "Null material_id found"
assert df["elements"].apply(lambda x: "Li" in x).all(), "Row missing Li in elements"

parquet_path = "/tmp/materials_bronze.parquet"
df.to_parquet(parquet_path, index=False)

client = storage.Client()
bucket = client.bucket("lithium-lake-raw-data")
blob = bucket.blob("bronze/materials.parquet")
blob.upload_from_filename(parquet_path)

print(f"Uploaded {len(df)} rows to gs://lithium-lake-raw-data/bronze/materials.parquet")
