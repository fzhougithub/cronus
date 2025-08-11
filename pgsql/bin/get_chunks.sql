WITH ordered AS (
  SELECT process_create_ts,
         ROW_NUMBER() OVER (ORDER BY process_create_ts) AS rownum
  FROM claimsprocess_other.claim_core
)
SELECT
  FLOOR((rownum - 1) / 30000) + 1 AS chunk_id,
  MIN(process_create_ts) AS starttime,
  MAX(process_create_ts) AS stoptime,
  COUNT(*) AS row_count
FROM ordered
GROUP BY chunk_id
ORDER BY chunk_id;
