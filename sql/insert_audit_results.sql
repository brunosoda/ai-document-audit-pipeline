---------------------- [RESET FIRST AUDIT STEP] RESET FIRST LLM EVALUATION FOR LOW-ACCURACY CASES (SANITIZED) ----------------------
DROP TABLE IF EXISTS tmp_reset;

CREATE TEMP TABLE tmp_reset AS
SELECT
    arc.case_uuid
FROM app_audit.audit_cases arc
LEFT JOIN app_validation.case_documents cd
    ON arc.case_uuid = cd.case_uuid
LEFT JOIN app_audit.case_accuracy a
    ON arc.case_uuid = a.case_uuid
CROSS JOIN LATERAL jsonb_array_elements(arc.raw_input_data::jsonb -> 'userInfos' -> 'DOCUMENT') elem
WHERE length(cd.file_path_optimized) > 5
-- AND a.accuracy_score < 1
  AND cd.type = 'DOCUMENT_FRONT'
  AND elem ->> 'key' = 'documentDescription'
  AND arc.case_uuid IN (
    {{ $json.uuid_list }}
  );

UPDATE app_audit.audit_cases
SET audit_rejected_criteria = NULL,
    audit_at = NULL,
    is_processed = NULL
WHERE case_uuid IN (
    SELECT case_uuid FROM tmp_reset
);

DELETE FROM app_audit.audit_results
WHERE case_uuid IN (
    SELECT case_uuid FROM tmp_reset
);

DELETE FROM app_audit.case_accuracy
WHERE case_uuid IN (
    SELECT case_uuid FROM tmp_reset
);
