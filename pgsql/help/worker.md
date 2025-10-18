**This confirms a serious problem!** You have:

- **181 total logical replication workers** (way too many!)
- **12 stuck workers** idle for more than 5 minutes
- **0 active workers** - meaning no replication is actually progressing

## Immediate Emergency Actions Needed

### 1. **Kill All Stuck Workers Immediately**
```sql
-- Kill workers idle for more than 5 minutes
SELECT pid, pg_terminate_backend(pid) as killed, 
       age(now(), state_change) as idle_time
FROM pg_stat_activity 
WHERE backend_type LIKE '%logical%'
AND state = 'idle'
AND age(now(), state_change) > interval '5 minutes';
```

### 2. **Check What's Consuming All Workers**
```sql
-- See which subscriptions are creating all these workers
SELECT 
    s.subname,
    count(*) as worker_count,
    count(CASE WHEN a.state = 'idle' THEN 1 END) as idle_workers,
    count(CASE WHEN a.state = 'active' THEN 1 END) as active_workers
FROM pg_stat_activity a
CROSS JOIN pg_subscription s
WHERE a.backend_type LIKE '%logical%'
AND a.query LIKE '%' || s.subname || '%'
GROUP BY s.subname
ORDER BY worker_count DESC;
```

### 3. **Check Table Sync Status Across All Subscriptions**
```sql
-- Get overview of all subscription table status
SELECT 
    s.subname,
    count(*) as total_tables,
    count(CASE WHEN sr.srsubstate = 'r' THEN 1 END) as ready_tables,
    count(CASE WHEN sr.srsubstate = 'i' THEN 1 END) as initializing_tables,
    count(CASE WHEN sr.srsubstate = 'd' THEN 1 END) as copying_tables,
    count(CASE WHEN sr.srsubstate = 'f' THEN 1 END) as failed_tables
FROM pg_subscription s
LEFT JOIN pg_subscription_rel sr ON s.oid = sr.srsubid
GROUP BY s.subname
ORDER BY failed_tables DESC, total_tables DESC;
```

## Root Cause Analysis

### A. **You're Hitting Resource Limits**
```sql
-- Check your limits vs current usage
SELECT 
    name,
    setting::int as configured,
    (SELECT count(*) FROM pg_stat_activity WHERE backend_type LIKE '%logical%') as current_usage,
    round((SELECT count(*) FROM pg_stat_activity WHERE backend_type LIKE '%logical%') * 100.0 / setting::int, 2) as percent_used
FROM pg_settings 
WHERE name IN ('max_logical_replication_workers', 'max_connections');
```

### B. **Check for Runaway Table Sync**
```sql
-- Find subscriptions with too many concurrent table syncs
SELECT 
    s.subname,
    (SELECT count(*) FROM pg_subscription_rel WHERE srsubid = s.oid) as table_count,
    current_setting('max_sync_workers_per_subscription')::int as max_workers_per_sub,
    (SELECT count(*) FROM pg_stat_activity 
     WHERE backend_type LIKE '%logical%' 
     AND query LIKE '%' || s.subname || '%') as current_workers
FROM pg_subscription s
ORDER BY current_workers DESC
LIMIT 10;
```

## Emergency Fix Procedure

### Step 1: **Stop the Bleeding - Kill Excess Workers**
```sql
-- Kill ALL idle logical workers (emergency measure)
SELECT count(pg_terminate_backend(pid)) as workers_killed
FROM pg_stat_activity 
WHERE backend_type LIKE '%logical%'
AND state = 'idle'
AND age(now(), state_change) > interval '1 minute';
```

### Step 2: **Temporarily Reduce Concurrency**
```sql
-- Drastically reduce concurrent workers
ALTER SYSTEM SET max_sync_workers_per_subscription = 2;
ALTER SYSTEM SET max_logical_replication_workers = 20;
SELECT pg_reload_conf();

-- Verify changes
SELECT name, setting FROM pg_settings 
WHERE name IN ('max_sync_workers_per_subscription', 'max_logical_replication_workers');
```

### Step 3: **Disable Problematic Subscriptions**
```sql
-- Disable all subscriptions temporarily
SELECT subname, ALTER SUBSCRIPTION subname DISABLE
FROM pg_subscription
WHERE subenabled = true;

-- Or disable specific problematic ones first
ALTER SUBSCRIPTION qc_finance_other_sub DISABLE;
ALTER SUBSCRIPTION qc_finance_global_sub DISABLE;
-- ... disable others showing high worker counts
```

### Step 4: **Restart in Controlled Manner**
```sql
-- Enable one subscription at a time with monitoring
ALTER SUBSCRIPTION least_problematic_sub ENABLE;

-- Monitor worker count
SELECT count(*) FROM pg_stat_activity WHERE backend_type LIKE '%logical%';
```

## Investigation Queries

### A. **What Are These Workers Actually Doing?**
```sql
-- Get details about the stuck workers
SELECT 
    pid,
    backend_type,
    state,
    state_change,
    age(now(), state_change) as idle_time,
    query,
    application_name
FROM pg_stat_activity 
WHERE backend_type LIKE '%logical%'
ORDER BY state_change ASC
LIMIT 20;
```

### B. **Check for Blocking/Locking Issues**
```sql
-- See if workers are waiting on locks
SELECT 
    a.pid,
    a.wait_event_type,
    a.wait_event,
    a.query,
    a.state
FROM pg_stat_activity a
WHERE a.backend_type LIKE '%logical%'
AND a.wait_event IS NOT NULL;
```

## Long-term Solution

### 1. **Implement Worker Limits per Subscription**
```sql
-- Much more conservative settings
ALTER SYSTEM SET max_sync_workers_per_subscription = 4;
ALTER SYSTEM SET max_logical_replication_workers = 50;
```

### 2. **Create Monitoring Dashboard**
```sql
-- Regular monitoring query
SELECT 
    now() as check_time,
    count(*) as total_workers,
    count(CASE WHEN state = 'idle' AND age(now(), state_change) > interval '2 minutes' THEN 1 END) as stuck_workers,
    count(CASE WHEN state = 'active' THEN 1 END) as active_workers,
    (SELECT count(*) FROM pg_subscription WHERE subenabled = true) as enabled_subs
FROM pg_stat_activity 
WHERE backend_type LIKE '%logical%';
```

### 3. **Set Up Automatic Cleanup**
```sql
-- Scheduled cleanup of stuck workers
CREATE OR REPLACE FUNCTION cleanup_replication_workers() RETURNS void AS $$
BEGIN
    PERFORM pg_terminate_backend(pid)
    FROM pg_stat_activity 
    WHERE backend_type LIKE '%logical%'
    AND state = 'idle'
    AND age(now(), state_change) > interval '10 minutes';
END;
$$ LANGUAGE plpgsql;
```

## **IMMEDIATE ACTION REQUIRED:**

1. **Run the kill query immediately** to free up resources
2. **Reduce the worker limits** to prevent recurrence
3. **Disable the most problematic subscriptions** 
4. **Investigate which specific tables are causing the hangs**

Your system is in a critical state with 181 workers! This will lead to:
- **Memory exhaustion**
- **Connection pool depletion** 
- **Complete replication stall**
- **Potential database instability**

Start with the emergency kill query right now!
