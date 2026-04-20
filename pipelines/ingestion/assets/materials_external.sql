/* @bruin
name: lithium_lake_data.materials_external
type: bq.sql
connection: gcp
uri: external://materials_external
depends:
    - ingestion.materials_bronze
@bruin */

-- we are pulling the raw materials data from GCS to BigQuery
CREATE OR REPLACE EXTERNAL TABLE `lithium-lake.lithium_lake_data.materials_external`
OPTIONS (
    format = 'PARQUET',
    uris = ['gs://lithium-lake-raw-data/bronze/materials.parquet']
);
