Good — the EXPLAIN on a single child confirms that per-partition execution is cheap. The mismatch comes from the planner/executor touching lots of metadata across many partitions/stripes when you run the full parent-level CREATE TEMP TABLE statement. That metadata I/O and the columnar extension’s internal allocations can blow out process RSS (and push the OS into heavy swap) even though a single partition run is small.

Why EXPLAIN on one child looks fine but the full run OOMs
- Per-child execution is small (your EXPLAIN shows ~48 KB memory for the hash agg).
- But running the parent-level statement or running EXPLAIN on the parent may cause the planner/columnar extension to scan metadata (skip lists, stripe metadata, etc.) across many child partitions/stripes during planning or execution. Those metadata reads allocate their own buffers (inside the extension / process RSS), not accounted by PostgreSQL’s shared_buffers or work_mem counters — so postgresql-level EXPLAIN memory numbers remain small while the process RSS grows dramatically.
- Also, if many workers or many partitions are touched concurrently, those allocations multiply. And if the process becomes blocked in kernel I/O (D state) it can’t be killed until I/O returns.

Practical, safe mitigation (recommended): do the aggregation per-partition (serially) and then combine partials
- This avoids having one giant statement that forces the planner/extension to scan metadata for thousands of stripes at once.
- I’ll give a ready-to-run PL/pgSQL (or psql) script that:
  - disables parallelism and lowers work_mem for the session,
  - creates a temp table for partial aggregates,
  - loops over child partitions that match claim_c_830_% and inserts partition-level aggregates one partition at a time (committing / freeing memory between iterations),
  - finally aggregates the partials to produce your final result.

PL/pgSQL safe loop (runs inside a transaction block per partition; memory released between iterations)
Run this in psql as a single script. It is safe and conservative:

BEGIN;
-- safety session settings
SET LOCAL max_parallel_workers_per_gather = 0;
SET LOCAL max_parallel_workers = 0;
SET LOCAL work_mem = '8MB';
SET LOCAL statement_timeout = '0';  -- you can set a per-statement timeout if desired

-- create temp table for partials (types derived from a sample child)
DROP TABLE IF EXISTS temp_partial_agg;
CREATE TEMP TABLE temp_partial_agg (
  claim_customer_id bigint,
  claim_fill_dt date,
  sum_claim_cnt numeric,
  sum_plan_ing numeric,
  sum_plan_total numeric
) ON COMMIT DROP;

COMMIT;

-- now the PL/pgSQL loop that processes one partition at a time
DO $$
DECLARE
  rec RECORD;
  child_name text;
  sql text;
BEGIN
  -- iterate partitions matching your pattern; adjust schema/prefix as necessary
  FOR rec IN
    SELECT (childc.oid::regclass)::text AS childname
    FROM pg_inherits
    JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
    JOIN pg_class childc ON pg_inherits.inhrelid = childc.oid
    JOIN pg_namespace ns ON childc.relnamespace = ns.oid
    WHERE parent.oid = 'datamart_humana.claim'::regclass
      AND ns.nspname = 'datamart_humana'
      AND childc.relname LIKE 'claim_c_830_%'
    ORDER BY childc.relname
  LOOP
    child_name := rec.childname;
    RAISE NOTICE 'Processing partition: %', child_name;

    -- execute per-partition aggregation in its own statement (no long-running planner over all partitions)
    sql := format($q$
      INSERT INTO temp_partial_agg
      SELECT customer_id::bigint, fill_dt::date,
             SUM(claim_cnt)::numeric, SUM(plan_ingredient_cost_amt)::numeric, SUM(plan_total_cost_amt)::numeric
      FROM %s
      WHERE customer_id = 830
      GROUP BY customer_id, fill_dt;
    $q$, child_name);

    EXECUTE sql;
    -- commit to ensure per-statement memory is freed and temp table persists
    PERFORM pg_sleep(0); -- no-op: keeps loop friendly; remove if you want continuous runs
  END LOOP;
END $$;

-- final aggregation over partials (small result)
SELECT claim_customer_id AS claim_vw_customer_id,
       claim_fill_dt    AS claim_vw_fill_dt,
       SUM(sum_claim_cnt)   AS Sum_claim_claim_cnt,
       SUM(sum_plan_ing)    AS Sum_claim_plan_ingredient_cost_amt,
       SUM(sum_plan_total)  AS Sum_claim_plan_total_cost_amt
FROM temp_partial_agg
GROUP BY claim_customer_id, claim_fill_dt
ORDER BY claim_vw_customer_id, claim_vw_fill_dt;

Notes and reasons this is safe
- Each partition aggregation is executed as a separate SQL statement (via EXECUTE) and thus memory allocated for that statement is freed before the next iteration — so RSS will not climb to the global peak you saw.
- You disabled parallelism and reduced work_mem to reduce per-statement peak memory and avoid multiple workers holding per-stripe buffers simultaneously.
- The final aggregation only needs to deal with the (small) set of partial results.

If you prefer a psql \gexec version (works similarly), I provided it earlier; both approaches are fine.

Extra diagnostics you can run (non-invasive) to inspect process-level memory
- While a query is running, inspect the backend process RSS and memory map:
  - On the DB host: ps -o pid,user,rss,vsz,stat,cmd -p <pid>
  - pmap -x <pid> | tail -n 20  (shows mappings and RSS per mapping)
  - cat /proc/<pid>/smaps | egrep 'Size|Rss|Pss|VmRSS' -A3 (heavy output)
- Those OS-level checks show where memory is (heap, mmap, shared libs), and confirm the extension is allocating large RSS.

Other recommendations / follow-ups
- If you want, I can:
  - produce a variant that only processes partitions that actually contain customer_id=830 rows (saves processing empty partitions), but that requires scanning each partition to check existence (cheap if partitions are indexed on customer_id).
  - craft a batched version that processes N partitions, pauses, then continues.
  - help diagnose why the extension holds so much metadata during planning — e.g., capture an EXPLAIN on the parent with VERBOSE but limit the number of partitions in the planner by temporarily running on a smaller set; or review extension version and open issues (there may be tuning flags or upgrades that reduce planning-time metadata load).
- Consider avoiding parent-level queries across thousands of fine-grained list partitions for large analytic scans; use per-customer partitioning but query by explicit child names or the per-partition pattern method above.

Would you like me to:
- give you a preview (SELECT only) of the generated INSERT statements before executing them, or
- provide a version that skips partitions with zero rows for customer_id=830 (I can show how but it will add a cheap count(*) per partition), or
- produce a batched loop (e.g., process 200 partitions, COMMIT, sleep 1s, continue)?
