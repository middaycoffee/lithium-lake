/* @bruin
name: lithium_lake_data.materials_silver
type: bq.sql
connection: gcp
materialization:
    type: table
    cluster_by:
        - crystal_system
depends:
    - uri: external://materials_external
columns: #these checks carried after the query is run
    - name: material_id
      checks:
          - name: not_null
          - name: unique
    - name: band_gap
      checks:
          - name: not_null
          - name: min
            value: 2.0
    - name: energy_above_hull
      checks:
          - name: not_null
          - name: min
            value: 0
          - name: max
            value: 0.05
@bruin */

-- flattens and types the bronze external table into the silver layer
SELECT
    -- primary key
    material_id,

    -- composition
    formula_pretty,
    ARRAY(SELECT el.element FROM UNNEST(elements.list) AS el) AS elements,

    -- thermodynamic stability
    CAST(energy_above_hull AS FLOAT64)              AS energy_above_hull,

    -- electronic insulation
    CAST(band_gap AS FLOAT64)                       AS band_gap,

    -- mechanical rigidity (suppress dendrites, >= 6.8 GPa threshold applied in Gold)
    CAST(shear_modulus.vrh AS FLOAT64)              AS shear_modulus,

    -- ductility / processing (used to compute Pugh Ratio K/G in Gold)
    CAST(bulk_modulus.vrh AS FLOAT64)               AS bulk_modulus,

    -- transport pathway / 3D percolation
    symmetry.crystal_system                         AS crystal_system,
    symmetry.symbol                                 AS space_group_symbol,
    symmetry.number                                 AS space_group_number,

    -- elasticity data availability flag (used in Gold to filter for Pugh Ratio and dendrite suppression)
    (shear_modulus IS NOT NULL AND bulk_modulus IS NOT NULL) AS has_elasticity_data,

    -- data freshness for dashboard
    CAST(last_updated AS TIMESTAMP)                  AS last_updated

FROM `lithium-lake.lithium_lake_data.materials_external`
