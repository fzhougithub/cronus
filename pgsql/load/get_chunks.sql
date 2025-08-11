SET WORK_MEM='1GB';

WITH ordered AS (
  SELECT clm_id::bigint,
         ROW_NUMBER() OVER (ORDER BY clm_id::bigint) AS rownum
  FROM stg_customer_320.dur_tmp
)
SELECT
  FLOOR((rownum - 1) / 500000) + 1 AS chunk_id,
  MIN(clm_id::bigint) AS startid,
  MAX(clm_id::bigint) AS stopid,
  COUNT(*) AS row_count
FROM ordered
GROUP BY chunk_id
ORDER BY chunk_id;
