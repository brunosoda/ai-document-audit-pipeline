--------------------------------------------------- GET SAMPLE STEP --------------------------------------------------------------------------------
SELECT
    c.tenant_id,
    t.name AS tenant,
    c.tenant_product AS product,
    TO_CHAR(c.created_at::date, 'YYYY-MM-DD') AS validation_date,
    COUNT(*) AS total_validations,
    ROUND(COUNT(*) * 0.05) AS validation_count
FROM onedocs_conference.conferences c
INNER JOIN onedocs_conference.tenants t
    ON c.tenant_id = t.id
WHERE c.status_type = 'AUTOMATIC'
  AND c.status IN ('APPROVED', 'REPROVED')
  AND c.created_at::date = CURRENT_DATE - 1
GROUP BY
    c.tenant_id,
    t.name,
    c.tenant_product,
    c.created_at::date
ORDER BY validation_date DESC;


--------------------------------------------------- [GET SAMPLE STEP] GET CASES FOR SAMPLE --------------------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_conference_validations;

CREATE TEMP TABLE tmp_conference_validations AS
SELECT
    conference_uuid,
    COALESCE(
        jsonb_agg(DISTINCT rule) FILTER (WHERE rule IS NOT NULL),
        '[]'::jsonb
    ) AS combined_rules,
    validation_summary,
    updated_at::date
FROM onedocs_conference.conference_validations cv
LEFT JOIN LATERAL (
    SELECT jsonb_array_elements(validation_request->'values') AS val
) v ON TRUE
LEFT JOIN LATERAL (
    SELECT jsonb_array_elements_text(v.val->'result'->'reproved_rules') AS rule
    UNION ALL
    SELECT jsonb_array_elements_text(v.val->'result'->'manually_pending_rules') AS rule
) r ON TRUE
WHERE created_at::date = CURRENT_DATE - 1
AND validation_name = 'final_validation'
GROUP BY conference_uuid, validation_summary, status, status_type, updated_at::date;

SELECT
  c.uuid,
  c.tenant_id,
  t.name AS tenant,
  c.tenant_product AS product,
  TO_CHAR(c.created_at::date, 'YYYY-MM-DD') AS validation_date,
  c.uploads,
  c.raw_input_data,
  c.created_at,
  tmp.combined_rules
FROM onedocs_conference.conferences c
INNER JOIN onedocs_conference.tenants t ON c.tenant_id = t.id
LEFT JOIN pg_temp.tmp_conference_validations tmp ON c.uuid = tmp.conference_uuid
WHERE c.status_type = 'AUTOMATIC'
  AND c.status IN ('APPROVED','REPROVED')
  AND c.tenant_id = {{ $json.tenant_id }}
  AND c.tenant_product = '{{ $json.product }}'
  AND c.created_at::date = '{{ $json.validation_date }}'::date
ORDER BY RANDOM()
LIMIT {{ $json.validation_count }};


--------------------------------------------------- [AUDIT MAIN STEP] GET CASES --------------------------------------------------------------------------------
SELECT
    ARC.conference_uuid,
    ARC.audit_uuid,
    ARC.tenant_id,
    ARC.tenant,
    ARC.product,
    ARC.validation_date,
    -- Monta a nova URL com "_optimized.jpg" antes de "&conference_uuid="
    LEFT(CD.orignal_url, POSITION('&conference_uuid=' IN CD.orignal_url) - 1)
        || '_optimized.jpg'
        || SUBSTRING(CD.orignal_url FROM POSITION('&conference_uuid=' IN CD.orignal_url))
        AS url_optimized,
    ARC.raw_input_data,
    ARC.combined_rules,
    elem ->> 'value' AS di_type
FROM onedocs_audit.audit_report_cases ARC
LEFT JOIN onedocs_conference.conference_documents CD ON ARC.conference_uuid = CD.conference_uuid
CROSS JOIN LATERAL jsonb_array_elements(ARC.raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') elem
WHERE length(file_path_optimized) > 5
AND ARC.validation_date = CURRENT_DATE - 1
AND CD.type = 'DOCUMENT_FRONT'
AND elem ->> 'key' = 'documentDescription'
AND ARC.di_reproved_criteria IS NULL
ORDER BY random()
LIMIT 50;
