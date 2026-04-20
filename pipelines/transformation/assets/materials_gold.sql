/* @bruin
name: lithium_lake_data.materials_gold
type: bq.sql
connection: gcp
depends:
    - lithium_lake_data.materials_silver
materialization:
    type: table
    cluster_by:
        - crystal_system
columns:
    - name: material_id
      checks:
          - name: not_null
          - name: unique
    - name: shear_modulus
      checks:
          - name: min
            value: 6.8
    - name: pugh_ratio
      checks:
          - name: min
            value: 1.75
@bruin */

SELECT
    material_id,
    formula_pretty,
    elements,
    crystal_system,
    space_group_symbol,
    space_group_number,
    energy_above_hull,
    band_gap,
    shear_modulus,
    bulk_modulus,
    last_updated,
    ROUND(bulk_modulus / shear_modulus, 4)  AS pugh_ratio,
    ROW_NUMBER() OVER (
        ORDER BY energy_above_hull ASC, band_gap DESC
    )                                        AS viability_rank

FROM `lithium-lake.lithium_lake_data.materials_silver`

WHERE has_elasticity_data = true
  AND shear_modulus >= 6.8
  AND (bulk_modulus / shear_modulus) > 1.75
  AND NOT EXISTS (
      SELECT 1 FROM UNNEST(elements) AS el
      WHERE el IN ('Pb', 'Tl', 'Hg', 'Cd', 'As')
  )
