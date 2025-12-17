------------------------------------------ [REPORT STEP] GET LOW ACCURACY CASES FOR VISUAL ANALYSIS ------------------------------
SELECT
    C.conference_uuid,
    C.validation_date,
    C.di_audit_at,
    C.di_is_reprocessed,
    C.di_reproved_criteria,
    ARRAY(
        SELECT r
        FROM unnest(C.combined_rules) AS r
        WHERE r IN (
            'di:is_invalid_image_quality',
            'di:is_wrong_document_type',
            'di:is_invalid_data_extraction',
            'di:is_document_forged',
            'di:is_name_mismatch',
            'di:is_document_number_mismatch',
            'di:is_birthdate_mismatch'
        )
    ) AS combined_rules,
    LEFT(CD.orignal_url, POSITION('&conference_uuid=' IN CD.orignal_url) - 1)
        || '_optimized.jpg'
        || SUBSTRING(CD.orignal_url FROM POSITION('&conference_uuid=' IN CD.orignal_url))
        AS file_url,
    elem  ->> 'value' AS name,
    eleme ->> 'value' AS document_number,
    elemento ->> 'value' AS cpf,
    elemen ->> 'value' AS birthdate,
    element ->> 'value' AS di_type,
    A.accuracy
FROM onedocs_audit.audit_report_cases C
LEFT JOIN onedocs_conference.conference_documents CD ON C.conference_uuid = CD.conference_uuid
LEFT JOIN onedocs_audit.di_cases_accuracy A ON C.conference_uuid = A.conference_uuid
CROSS JOIN LATERAL jsonb_array_elements(raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') elem
CROSS JOIN LATERAL jsonb_array_elements(raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') eleme
CROSS JOIN LATERAL jsonb_array_elements(raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') elemento
CROSS JOIN LATERAL jsonb_array_elements(raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') elemen
CROSS JOIN LATERAL jsonb_array_elements(raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') element
WHERE C.di_is_processed = TRUE
--  AND C.di_audit_at >= CURRENT_DATE
  AND C.validation_date >= CURRENT_DATE - 1
  AND length(CD.file_path_optimized) > 5
  AND A.accuracy < 1
--  AND C.di_is_reprocessed IS NULL
  AND CD.type = 'DOCUMENT_FRONT'
  AND elem  ->> 'key' = 'name'
  AND eleme ->> 'key' = 'document'
  AND elemen ->> 'key' = 'birthDate'
  AND element ->> 'key' = 'documentDescription'
  AND elemento ->> 'key' = 'cpf'
ORDER BY accuracy;
