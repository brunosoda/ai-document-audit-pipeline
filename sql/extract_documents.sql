-----------------------------------------------------------
------------- [GET SAMPLE STEP] GET GROUP CASES (sanitized)
SELECT
    c.account_id,
    a.name AS account,
    c.account_product AS product,
    TO_CHAR(c.created_at::date, 'YYYY-MM-DD') AS validation_date,
    COUNT(*) AS total_validations,
    ROUND(COUNT(*) * 0.05) AS sample_count
FROM app_validation.conferences c
INNER JOIN app_validation.accounts a
    ON c.account_id = a.id
WHERE c.process_type = 'AUTOMATED'
  AND c.result_status IN ('APPROVED', 'REJECTED')
  AND c.created_at::date = CURRENT_DATE - 1
GROUP BY
    c.account_id,
    a.name,
    c.account_product,
    c.created_at::date
ORDER BY validation_date DESC;



-----------------------------------------------------------
-------- [GET SAMPLE STEP] GET CASES FOR SAMPLE (sanitized)
DROP TABLE IF EXISTS tmp_validation_rules;

CREATE TEMP TABLE tmp_validation_rules AS
SELECT
    conference_uuid,
    COALESCE(
        jsonb_agg(DISTINCT rule) FILTER (WHERE rule IS NOT NULL),
        '[]'::jsonb
    ) AS combined_rules,
    validation_summary,
    updated_at::date
FROM app_validation.conference_validations cv
LEFT JOIN LATERAL (
    SELECT jsonb_array_elements(validation_request->'values') AS val
) v ON TRUE
LEFT JOIN LATERAL (
    SELECT jsonb_array_elements_text(v.val->'result'->'failed_rules') AS rule
    UNION ALL
    SELECT jsonb_array_elements_text(v.val->'result'->'pending_rules') AS rule
) r ON TRUE
WHERE created_at::date = CURRENT_DATE - 1
  AND validation_name = 'final_validation'
GROUP BY conference_uuid, validation_summary, updated_at::date;

SELECT
  c.uuid,
  c.account_id,
  a.name AS account,
  c.account_product AS product,
  TO_CHAR(c.created_at::date, 'YYYY-MM-DD') AS validation_date,
  c.uploads,
  c.raw_input_data,
  c.created_at,
  tmp.combined_rules
FROM app_validation.conferences c
INNER JOIN app_validation.accounts a ON c.account_id = a.id
LEFT JOIN pg_temp.tmp_validation_rules tmp ON c.uuid = tmp.conference_uuid
WHERE c.process_type = 'AUTOMATED'
  AND c.result_status IN ('APPROVED','REJECTED')
  AND c.account_id = {{ $json.account_id }}
  AND c.account_product = '{{ $json.product }}'
  AND c.created_at::date = '{{ $json.validation_date }}'::date
ORDER BY RANDOM()
LIMIT {{ $json.sample_count }};



-----------------------------------------------------------
------------------- [AUDIT MAIN STEP] GET CASES (sanitized)
SELECT
    arc.conference_uuid,
    arc.audit_uuid,
    arc.account_id,
    arc.account,
    arc.product,
    arc.validation_date,

    -- Build the optimized URL by inserting "_optimized.jpg" before "&conference_uuid="
    LEFT(cd.original_url, POSITION('&conference_uuid=' IN cd.original_url) - 1)
        || '_optimized.jpg'
        || SUBSTRING(cd.original_url FROM POSITION('&conference_uuid=' IN cd.original_url))
        AS url_optimized,

    arc.raw_input_data,
    arc.combined_rules,
    elem ->> 'value' AS doc_type
FROM app_audit.audit_report_cases arc
LEFT JOIN app_validation.conference_documents cd
    ON arc.conference_uuid = cd.conference_uuid
CROSS JOIN LATERAL jsonb_array_elements(arc.raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') elem
WHERE length(cd.file_path_optimized) > 5
  AND arc.validation_date = CURRENT_DATE - 1
  AND cd.type = 'DOCUMENT_FRONT'
  AND elem ->> 'key' = 'documentDescription'
  AND arc.audit_rejected_criteria IS NULL
ORDER BY random()
LIMIT 50;
