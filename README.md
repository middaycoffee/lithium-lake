# Lithium Lake — Solid-State Battery Electrolyte Discovery Pipeline

Capstone project for <a href="https://github.com/DataTalksClub/data-engineering-zoomcamp" target="_blank">Data Engineering Zoomcamp 2026</a>.

A data engineering pipeline that queries the <a href="https://github.com/materialsproject" target="_blank">Materials Project</a> database, processes ~2,700 lithium-containing compounds through a Medallion Architecture on GCP, and surfaces the most viable solid-state battery electrolyte candidates ranked by scientific criteria.

![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python)
![GCP](https://img.shields.io/badge/Cloud-GCP-orange?logo=googlecloud)
![BigQuery](https://img.shields.io/badge/Warehouse-BigQuery-blue?logo=googlebigquery)
![Docker](https://img.shields.io/badge/Container-Docker-2496ED?logo=docker)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)
![CI](https://github.com/middaycoffeemiddaycoffee/lithium-lake/actions/workflows/validate.yml/badge.svg)

---

## Table of Contents

- [Why This Project](#why-this-project)
- [Architecture](#architecture)
- [Scientific Criteria](#scientific-criteria)
- [Stack](#stack)
- [Project Structure](#project-structure)
- [Pipeline Detail](#pipeline-detail)
- [Data Quality](#data-quality)
- [Dashboard](#dashboard)
- [Results](#results)
- [How to Run](#how-to-run)
- [CI/CD](#cicd)
- [Data Source](#data-source)

---

## Why This Project

Solid-state batteries are one of the most promising directions in energy storage — higher energy density, no flammable liquid electrolyte, longer lifespan. The bottleneck is finding the right solid electrolyte material: it needs to be stable, electrically insulating, and mechanically tough enough to suppress lithium dendrite growth.

The <a href="https://github.com/materialsproject" target="_blank">Materials Project</a> has computational data on hundreds of thousands of inorganic materials. This project builds a pipeline to filter, clean, and rank the candidates that meet the physics requirements — turning a raw API dump into an actionable shortlist of 47 materials.

---

## Architecture

The pipeline follows a **Medallion Architecture**: raw data lands in Bronze, gets cleaned and typed in Silver, and the science logic lives in Gold. Orchestrated with <a href="https://github.com/bruin-data/bruin" target="_blank">Bruin</a>, infrastructure provisioned via <a href="https://github.com/hashicorp/terraform" target="_blank">Terraform</a>.

```mermaid
flowchart LR
    A([Materials Project API]) --> B

    subgraph ingestion [Ingestion Pipeline]
        B[Bronze\nPython Asset\nGCS Parquet] --> C[External Table\nBigQuery DDL]
    end

    subgraph transformation [Transformation Pipeline]
        D[Silver\nFlatten & Type\nBigQuery Table] --> E[Gold\nFilter & Rank\nBigQuery Table]
    end

    C --> D
    E --> F([Looker Studio\nDashboard])
```

<!-- Architecture diagram image -->
<!-- ![Architecture](images/architecture.png) -->

---

## Scientific Criteria

The Gold layer applies four physical requirements for a viable solid electrolyte:

| Criterion | Threshold | Why |
|---|---|---|
| Thermodynamic stability | `energy_above_hull ≤ 0.05 eV/atom` | Material won't decompose under battery conditions |
| Electronic insulation | `band_gap ≥ 2.0 eV` | Prevents short circuits through the electrolyte |
| Dendrite suppression | `shear_modulus ≥ 6.8 GPa` | Mechanically blocks lithium dendrite growth |
| Ductility (Pugh Ratio) | `bulk_modulus / shear_modulus > 1.75` | Material can be processed without cracking |

Materials containing toxic elements (`Pb`, `Tl`, `Hg`, `Cd`, `As`) are excluded regardless of their mechanical properties.

---

## Stack

| Layer | Tool | Why |
|---|---|---|
| Orchestration | Bruin | Native BigQuery support, clean asset-based DAGs, built-in data quality checks |
| Infrastructure | Terraform | Reproducible GCS + BigQuery provisioning, version-controlled infra |
| Raw storage | Google Cloud Storage | Cheap Parquet storage, natively queryable by BigQuery external tables |
| Warehouse | BigQuery | Serverless, scales to any size, external table support avoids double storage |
| Containerization | Docker | One-command reproducibility for reviewers with zero local setup |
| CI/CD | GitHub Actions | Validates pipeline assets on every push, free for public repos |
| Dashboard | Looker Studio | Native BigQuery connector, shareable public URL, no code required |
| Data source | [Materials Project API](https://next-gen.materialsproject.org/api) | Open DFT database with 150k+ inorganic materials and elasticity data |

---

## Project Structure

```
lithium-lake/
├── pipelines/
│   ├── ingestion/
│   │   ├── pipeline.yml
│   │   └── assets/
│   │       ├── materials_bronze.py       # API → GCS
│   │       └── materials_external.sql    # GCS → BigQuery external table
│   └── transformation/
│       ├── pipeline.yml
│       └── assets/
│           ├── materials_silver.sql      # flatten, cast, clean
│           └── materials_gold.sql        # filter, rank, output
├── .github/
│   └── workflows/
│       └── validate.yml                  # Bruin validation on push
├── Dockerfile
├── docker-compose.yml
├── main.tf                               # GCS bucket + BigQuery dataset
├── variables.tf
├── requirements.txt
└── .env.example
```

---

## Pipeline Detail

### Bronze — `ingestion.materials_bronze`

Queries the Materials Project API for all lithium-containing compounds with 2–4 elements, thermodynamic stability within 50 meV/atom of the convex hull, and a band gap above 2 eV. Results are serialized to Parquet and uploaded to GCS.

Checks run after upload:
- Row count > 0
- `material_id` is never null
- Every row contains Li in its elements list

### External Table — `lithium_lake_data.materials_external`

A `CREATE OR REPLACE EXTERNAL TABLE` DDL that points BigQuery at the GCS Parquet. No data is copied — BigQuery reads the file directly. Runs after Bronze to always pick up the latest schema.

### Silver — `lithium_lake_data.materials_silver`

Flattens the nested Parquet structures into typed BigQuery columns:
- `shear_modulus.vrh` and `bulk_modulus.vrh` → `FLOAT64` scalars
- `symmetry.crystal_system`, `.symbol`, `.number` → flat STRING/INT columns
- `elements.list[].element` → `ARRAY<STRING>`
- `last_updated` → `TIMESTAMP`
- Adds `has_elasticity_data` boolean flag (shear and bulk modulus are sparse in the database)

Clustered by `crystal_system`. Quality checks validate that the Bronze API filters held.

### Gold — `lithium_lake_data.materials_gold`

Applies the four scientific thresholds. Computes `pugh_ratio = bulk_modulus / shear_modulus`. Ranks all passing candidates by `energy_above_hull ASC, band_gap DESC` — lower hull energy and higher band gap both indicate a better electrolyte.

Result: **47 candidates** from 2,720 input materials.

---

## Data Quality

Quality checks run automatically after each asset materializes.

**Bronze (Python assertions):**
- `len(df) > 0`
- `material_id` not null
- `Li` in every `elements` list

**Silver (Bruin column checks):**
- `material_id`: not null, unique
- `band_gap`: not null, min 2.0
- `energy_above_hull`: not null, min 0, max 0.05

**Gold (Bruin column checks):**
- `material_id`: not null, unique
- `shear_modulus`: min 6.8
- `pugh_ratio`: min 1.75

---

## Dashboard

The Gold table is connected to a Looker Studio dashboard showing:

- Crystal system distribution among the 47 candidates
- Scatter plot: `band_gap` vs `energy_above_hull` (the stability-insulation tradeoff)
- Top candidates table ranked by viability score

<!-- Dashboard screenshot -->
<!-- ![Dashboard](images/dashboard.png) -->

<!-- Scatter plot image -->
<!-- ![Band Gap vs Energy Above Hull](images/scatter.png) -->

---

## Results

Starting from 2,720 lithium-containing compounds, the pipeline narrows to **47 viable solid-state electrolyte candidates** after applying all four scientific criteria and excluding toxic elements.

<!-- Results table image -->
<!-- ![Top 10 Candidates](images/results.png) -->

Key observations:
- Most candidates with elasticity data are cubic or orthorhombic — crystal systems known for isotropic mechanical properties
- Several candidates sit at `energy_above_hull = 0`, meaning they are exactly on the convex hull and thermodynamically optimal
- The Pugh Ratio filter is the most selective after the elasticity data requirement, cutting ~60% of remaining candidates

---

## How to Run

### Prerequisites

- Docker and Docker Compose
- A [Materials Project API key](https://next-gen.materialsproject.org/api)
- A GCP service account JSON with `BigQuery Admin` and `Storage Admin` roles

### Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/middaycoffeemiddaycoffee/lithium-lake.git
   cd lithium-lake
   ```

2. Create a `.env` file from the example:
   ```bash
   cp .env.example .env
   ```
   Fill in your Materials Project API key.

3. Place your GCP service account key at the project root:
   ```
   gcp-service.json
   ```

4. Provision GCP infrastructure with Terraform:
   ```bash
   terraform init
   terraform apply
   ```

5. Run the full pipeline:
   ```bash
   docker compose up
   ```

This runs Bronze → External → Silver → Gold in the correct dependency order. The final Gold table will be available in BigQuery at `lithium-lake.lithium_lake_data.materials_gold`.

---

## CI/CD

On every push to `main`, GitHub Actions runs `bruin validate` against both pipelines to catch broken asset definitions before they reach production.

---

## Data Source

All materials data comes from <a href="https://github.com/materialsproject" target="_blank">The Materials Project</a>, a DOE-funded initiative that provides open computational data on inorganic materials. The pipeline uses the `mp-api` Python client to query the `materials/summary` endpoint.

The database is updated periodically as new DFT calculations are completed — the `last_updated` field tracks when each material's data was last revised.
