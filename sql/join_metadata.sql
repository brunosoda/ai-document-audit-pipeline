------------------------------------------ [REPORT STEP] GET LOW-ACCURACY CASES FOR VISUAL REVIEW (SANITIZED) ------------------------------
SELECT
    c.case_uuid,
    c.validation_date,
    c.audit_at,
    c.is_reprocessed,
    c.audit_rejected_criteria,
    ARRAY(
        SELECT r
        FROM unnest(c.combined_rules) AS r
        WHERE r IN (
            'rule:invalid_image_quality',
            'rule:wrong_document_type',
            'rule:invalid_data_extraction',
            'rule:document_forgery_suspected',
            'rule:name_mismatch',
            'rule:document_number_mismatch',
            'rule:birthdate_mismatch'
        )
    ) AS filtered_rules,
    LEFT(cd.original_url, POSITION('&case_uuid=' IN cd.original_url) - 1)
        || '_optimized.jpg'
        || SUBSTRING(cd.original_url FROM POSITION('&case_uuid=' IN cd.original_url))
        AS file_url,
    name_elem      ->> 'value' AS person_name,
    doc_elem       ->> 'value' AS document_number,
    id_elem        ->> 'value' AS personal_identifier,
    birth_elem     ->> 'value' AS birthdate,
    type_elem      ->> 'value' AS document_type,
    a.accuracy_score
FROM app_audit.audit_cases c
LEFT JOIN app_validation.case_documents cd
    ON c.case_uuid = cd.case_uuid
LEFT JOIN app_audit.case_accuracy a
    ON c.case_uuid = a.case_uuid
CROSS JOIN LATERAL jsonb_array_elements(c.raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') name_elem
CROSS JOIN LATERAL jsonb_array_elements(c.raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') doc_elem
CROSS JOIN LATERAL jsonb_array_elements(c.raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') id_elem
CROSS JOIN LATERAL jsonb_array_elements(c.raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') birth_elem
CROSS JOIN LATERAL jsonb_array_elements(c.raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') type_elem
WHERE c.is_processed = TRUE
  AND c.validation_date >= CURRENT_DATE - 1
  AND length(cd.file_path_optimized) > 5
  AND a.accuracy_score < 1
  AND cd.type = 'DOCUMENT_FRONT'
  AND name_elem  ->> 'key' = 'name'
  AND doc_elem   ->> 'key' = 'document_number'
  AND id_elem    ->> 'key' = 'personal_id'
  AND birth_elem ->> 'key' = 'birth_date'
  AND type_elem  ->> 'key' = 'document_type'
ORDER BY a.accuracy_score;
