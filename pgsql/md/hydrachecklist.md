## 1) Will `ALTER TABLE ... SET (stripe_row_limit, chunk_group_row_limit)` rewrite data?

**No — it does NOT rewrite existing data.**

These settings are **columnar storage options (reloptions / metadata only)**.

So for your case:

```sql id="q9k2aa"
ALTER TABLE datamart_humana.claim_20260320
SET (stripe_row_limit = 50000);
```

### What actually happens:

* ✔ updates catalog metadata (like `pg_class.reloptions` / columnar metadata table)
* ✔ affects **future writes / new stripes**
* ✔ affects **vacuum / reorganization operations only if they rewrite stripes**
* ❌ does NOT rewrite existing stripes
* ❌ does NOT rebuild 1116 partitions

---

### For your 2-layer partitioned table (1116 leaf partitions)

This is also important:

* Each **leaf partition stores its own columnar files**
* Setting on parent **does not automatically propagate to children** (in most Hydra/Citus columnar implementations)

So you likely need:

```sql id="x8p3ll"
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT inhrelid::regclass AS part
    FROM pg_inherits
    WHERE inhparent = 'datamart_humana.claim_20260320'::regclass
  LOOP
    EXECUTE format(
      'ALTER TABLE %s SET (stripe_row_limit = 50000, chunk_group_row_limit = 5000)',
      r.part
    );
  END LOOP;
END $$;
```

---

### Important consequence

Because no rewrite happens:

* existing stripes still have old layout
* improvement is **gradual**
* worst-case queries may still hit old “large stripe behavior”

If you need full consistency → only `REPACK / VACUUM FULL / columnar rewrite` would fix old data (expensive).

---

# 2) “Hydra Safe Execution Profile” (practical design)

You are basically trying to solve 3 problems:

### A. Prevent memory explosion

### B. Prevent IO storm (D-state backend)

### C. Make kill/terminate reliable again

We solve this in layers.

---

# LAYER 1 — Role-based execution control (VERY IMPORTANT)

Create a dedicated role:

```sql id="r1k9aa"
CREATE ROLE hydra_analytics;
```

---

## 1.1 Memory safety

```sql id="m2p8bb"
ALTER ROLE hydra_analytics SET work_mem = '16MB';
ALTER ROLE hydra_analytics SET maintenance_work_mem = '256MB';
```

---

## 1.2 Stop parallel IO storms (critical for standby)

```sql id="p7k1cc"
ALTER ROLE hydra_analytics SET max_parallel_workers_per_gather = 0;
ALTER ROLE hydra_analytics SET max_parallel_workers = 0;
```

👉 This alone often fixes:

* IO spikes
* “unkillable backend” behavior
* CPU IOwait storms

---

## 1.3 Prevent giant hash joins

```sql id="h3q2dd"
ALTER ROLE hydra_analytics SET enable_hashjoin = off;
ALTER ROLE hydra_analytics SET enable_mergejoin = on;
```

Why:

* hash join + columnar scan = memory spike + long critical section

---

# LAYER 2 — Columnar execution limits (your discovery)

Apply per-role defaults:

```sql id="c4r1ee"
ALTER ROLE hydra_analytics SET columnar.stripe_row_limit = 50000;
ALTER ROLE hydra_analytics SET columnar.chunk_group_row_limit = 5000;
```

(if Hydra supports GUC-based control; otherwise enforce via table-level settings like you did)

---

# LAYER 3 — Query time safety valves

## 3.1 Hard stop long queries

```sql id="t9k3ff"
ALTER ROLE hydra_analytics SET statement_timeout = '2min';
```

---

## 3.2 Kill runaway temp files (VERY important for IO storms)

```sql id="f8m2gg"
ALTER ROLE hydra_analytics SET temp_file_limit = '10GB';
```

This prevents:

* disk saturation
* IO hang that makes kill impossible

---

# LAYER 4 — OS / cgroup protection (standby survival layer)

This is what keeps your VM alive.

```ini id="c1p7hh"
MemoryHigh=240G
MemoryMax=280G
```

Why not 300G?

Because PostgreSQL + OS cache + kernel needs breathing room.

---

## Optional but powerful:

```ini id="o9k4ii"
IOWeight=100
```

and separate heavy analytics vs replication priority (if you split services later).

---

# LAYER 5 — “Kill reliability strategy” (this is the missing piece in most systems)

The reason your kill fails is usually:

### backend is in:

* D-state (kernel IO wait)
* or long extension critical section

So we shift from “kill harder” → “prevent entering unkillable state”.

---

## 5.1 Detect bad queries early (PSI-based watchdog)

Monitor:

```bash id="psiw1"
cat /proc/pressure/io
cat /proc/pressure/memory
```

Trigger when:

```text id="thr1"
some avg10 > threshold
```

Then:

```sql id="kill1"
SELECT pg_terminate_backend(pid)
```

before it becomes stuck.

---

## 5.2 Backend health scoring (recommended)

Continuously compute:

```sql id="sc1"
SELECT pid,
       now() - query_start AS runtime,
       wait_event_type,
       wait_event,
       pg_blocking_pids(pid)
FROM pg_stat_activity;
```

Kill if:

* runtime > X
* AND waiting on IO
* AND scanning columnar table

---

# LAYER 6 — Hydra-specific tuning summary

For your system (based on symptoms):

### SAFE standby profile:

```text id="final1"
stripe_row_limit:        50k
chunk_group_row_limit:    5k
compression:              zstd 3
parallel workers:         OFF
work_mem:                 16MB
temp_file_limit:          10GB
statement_timeout:        2 min
```

---

# Key insight (very important)

Your original problem:

> kill doesn’t work + IO storm + standby freeze

is NOT a “kill problem”.

It is:

```text id="root1"
query enters uninterruptible IO / columnar decompression critical region
→ kernel blocks backend
→ signals delayed
→ system saturates IO
```

So:

✔ tuning stripe/chunk reduces atomic IO burst size
✔ disabling parallelism prevents IO amplification
✔ temp limits prevent disk saturation
✔ cgroups protect VM survival

---

# If you want next step

I can help you build:

### 👉 “Hydra Query Admission Control System”

That includes:

* pre-execution query cost estimation
* automatic rejection of dangerous joins
* partition fanout detection
* columnar stripe scan estimator
* per-role query budget (CPU + IO)

That is usually the final step before these systems become stable in production.



