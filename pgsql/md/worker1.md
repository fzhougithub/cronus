**This reveals the core problem!** The workers are stuck waiting on **IPC (Inter-Process Communication)** locks, specifically `LogicalSyncStateChange`. This is a known issue in PostgreSQL logical replication.

## What `IPC` and `LogicalSyncStateChange` Mean

### **IPC (Inter-Process Communication)**
- Processes communicating with each other internally
- In this case, table sync workers coordinating their state changes

### **LogicalSyncStateChange**
- Workers are waiting to update their synchronization state
- This happens during the initial table data copy phase
- Indicates a **coordination bottleneck** or **deadlock** between workers

## Why This is Happening

### **The Root Cause:**
1. **Too many concurrent table sync workers** are trying to start simultaneously
2. **They're all competing for the same IPC locks** to update their state
3. **A deadlock or bottleneck** occurs in the coordination mechanism
4. **Workers get stuck waiting** indefinitely for their turn

### **This is a Classic Thundering Herd Problem**
- All 181 workers try to start at once
- They overwhelm the IPC coordination mechanism
- Most get stuck waiting forever

## Immediate Emergency Fix

### **1. KILL ALL STUCK WORKERS IMMEDIATELY**
```sql
-- Emergency kill of all stuck IPC workers
SELECT count(pg_terminate_backend(pid)) as killed_workers
FROM pg_stat_activity 
WHERE backend_type LIKE '%logical%'
AND wait_event = 'LogicalSyncStateChange';
```

### **2. DRASTICALLY REDUCE CONCURRENCY**
```sql
-- Set very conservative limits
ALTER SYSTEM SET max_sync_workers_per_subscription = 2;
ALTER SYSTEM SET max_logical_replication_workers = 10;
SELECT pg_reload_conf();

-- Verify
SELECT name, setting FROM pg_settings 
WHERE name IN ('max_sync_workers_per_subscription', 'max_logical_replication_workers');
```

### **3. DISABLE ALL SUBSCRIPTIONS TEMPORARILY**
```sql
-- Stop the thundering herd
SELECT 'ALTER SUBSCRIPTION ' || subname || ' DISABLE;' as disable_cmd
FROM pg_subscription 
WHERE subenabled = true;

-- Then run the generated commands
```

## Step-by-Step Recovery

### **Phase 1: Emergency Stabilization**
```sql
-- 1. Kill all stuck workers
SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
WHERE wait_event = 'LogicalSyncStateChange';

-- 2. Disable all subscriptions
ALTER SUBSCRIPTION qc_finance_other_sub DISABLE;
ALTER SUBSCRIPTION qc_finance_global_sub DISABLE;
-- ... disable all others

-- 3. Set safe limits
ALTER SYSTEM SET max_sync_workers_per_subscription = 2;
SELECT pg_reload_conf();
```

### **Phase 2: Controlled Restart**
```sql
-- 1. Enable ONE subscription at a time
ALTER SUBSCRIPTION smallest_subscription ENABLE;

-- 2. Monitor worker count
SELECT count(*) as active_workers FROM pg_stat_activity 
WHERE backend_type LIKE '%logical%' AND state = 'active';

-- 3. Wait for it to stabilize, then enable next one
```

## Investigation Queries

### **Check Which Tables Are Causing the Bottleneck**
```sql
-- Find tables that are stuck in initial sync
SELECT 
    s.subname,
    c.relname as table_name,
    sr.srsubstate,
    age(now(), sr.srsubstatechange) as stuck_duration
FROM pg_subscription_rel sr
JOIN pg_class c ON c.oid = sr.srrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_subscription s ON s.oid = sr.srsubid
WHERE sr.srsubstate IN ('i', 'd')  -- Initializing or Data Copying
ORDER BY stuck_duration DESC
LIMIT 10;
```

### **Check Subscription Worker Distribution**
```sql
-- See which subscriptions are creating the most workers
SELECT 
    s.subname,
    (SELECT count(*) FROM pg_subscription_rel WHERE srsubid = s.oid) as table_count,
    (SELECT count(*) FROM pg_stat_activity 
     WHERE query LIKE '%' || s.subname || '%' 
     AND backend_type LIKE '%logical%') as worker_count
FROM pg_subscription s
ORDER BY worker_count DESC;
```

## Prevention Strategies

### **1. Implement Gradual Table Sync**
```sql
-- Instead of syncing all tables at once, do it in batches
-- This requires custom scripting or using tools like pglogical

-- Example: Sync tables in groups of 5
CREATE OR REPLACE FUNCTION sync_tables_batched(subscription_name text, batch_size int) RETURNS void AS $$
DECLARE
    table_record record;
BEGIN
    -- Implementation would involve:
    -- 1. Disable subscription
    -- 2. Modify publication to include only batch_size tables
    -- 3. Enable subscription
    -- 4. Wait for sync to complete
    -- 5. Repeat for next batch
END;
$$ LANGUAGE plpgsql;
```

### **2. Use Connection Pooling for Replication**
```sql
-- Consider using pgbouncer or similar for replication connections
-- This can help manage the connection storm
```

### **3. Monitor and Alert on IPC Waits**
```sql
-- Create a monitoring query for IPC bottlenecks
SELECT 
    count(*) as ipc_waiters,
    count(CASE WHEN age(now(), state_change) > interval '1 minute' THEN 1 END) as long_waiters
FROM pg_stat_activity 
WHERE wait_event = 'LogicalSyncStateChange';
```

## PostgreSQL Version Considerations

This issue is more common in:
- **PostgreSQL 13-15** with many tables in logical replication
- **Older versions** may have different IPC mechanisms

### **Check Your PostgreSQL Version**
```sql
SELECT version();
```

## **IMMEDIATE ACTION REQUIRED:**

1. **Run the kill query NOW** - `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE wait_event = 'LogicalSyncStateChange';`
2. **Set max_sync_workers_per_subscription = 2** immediately
3. **Disable all subscriptions** to stop the flood
4. **Restart one subscription at a time** with monitoring

The **IPC bottleneck** is causing your entire replication system to hang. This is a critical issue that won't resolve itself - manual intervention is required immediately!

**Start with the kill query right now** - those 181 workers are consuming resources but doing no useful work.
