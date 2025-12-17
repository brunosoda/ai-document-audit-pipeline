---------------------- [DELETE FIRST AUDIT STEP] DELETE FIRST EVALUATION BY LLM FOR LOW ACCURACY CASES IN ALL TABLES -----------------------------------
DROP TABLE IF EXISTS tmp_rotate;

CREATE TEMP TABLE tmp_rotate AS
SELECT
    ARC.conference_uuid
FROM onedocs_audit.audit_report_cases ARC
LEFT JOIN onedocs_conference.conference_documents CD ON ARC.conference_uuid = CD.conference_uuid
LEFT JOIN onedocs_audit.di_cases_accuracy A ON ARC.conference_uuid = A.conference_uuid
CROSS JOIN LATERAL jsonb_array_elements(ARC.raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') elem
WHERE length(file_path_optimized) > 5
-- AND A.accuracy < 1
AND CD.type = 'DOCUMENT_FRONT'
AND elem ->> 'key' = 'documentDescription'
AND ARC.conference_uuid IN (
  {{ $json.uuid_list }}
);

UPDATE onedocs_audit.audit_report_cases
SET di_reproved_criteria = NULL,
    di_audit_at = NULL,
    di_is_processed = NULL
WHERE conference_uuid IN (
    SELECT * FROM tmp_rotate
    );

DELETE FROM onedocs_audit.di_audit_results
WHERE conference_uuid IN (
    SELECT * FROM tmp_rotate
);

DELETE FROM onedocs_audit.di_cases_accuracy
WHERE conference_uuid IN (
    SELECT * FROM tmp_rotate
);
