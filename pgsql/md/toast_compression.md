Excellent question! The difference happens because of **fundamentally different data insertion mechanisms** between normal operations and logical replication initial copy.

## Why Publication Side Works Correctly

### Normal Operations (Publisher):
```sql
-- When applications insert data normally:
INSERT INTO table VALUES (large_jsonb_data);

-- PostgreSQL's process:
1. Receives the raw JSONB data
2. Checks size against TOAST threshold (~2KB)
3. **Compresses** the data using LZ compression
4. If still too large, moves to TOAST table
5. Stores with proper compression metadata
```

**Result**: Efficient TOAST compression on publisher

## Why Subscription Side Fails

### Logical Replication Initial Copy:
```sql
-- What happens during initial sync:
COPY table FROM STDIN WITH BINARY;

-- The process:
1. Logical decoding extracts **already-TOASTed values** 
2. Gets the **decompressed values** (not the compressed chunks)
3. Uses BINARY COPY protocol which doesn't recompress
4. Inserts decompressed values directly
5. **No compression applied** - stores as-is in TOAST
```

## The Technical Root Cause

### 1. **Logical Decoding Behavior**
```c
// Logical decoding gives you the final reconstructed values
// not the compressed TOAST chunks
Datum toast_value = heap_getattr(tuple, attnum, tupDesc, &isnull);
// This returns DECOMPRESSED values
```

### 2. **COPY BINARY Protocol**
- Designed for speed, not storage efficiency
- Doesn't reapply TOAST compression logic
- Transfers values as they're presented

### 3. **Missing Compression Context**
The replication process loses the information that these values were originally compressed and should be recompressed.

## Why pg_dump Works Better

### pg_dump Approach:
```sql
-- pg_dump generates:
INSERT INTO table VALUES ('{"large": "json", "data": "here"}');

-- During pg_restore:
1. PostgreSQL receives the INSERT statement  
2. Processes it through normal SQL engine
3. **Applies standard TOAST compression** 
4. Stores efficiently like normal operations
```

## PostgreSQL's Design Choice

This is actually **intentional behavior** in PostgreSQL:

1. **Correctness over Efficiency**: Guarantee data integrity first
2. **Performance**: BINARY COPY is faster for initial sync
3. **Simplicity**: Avoid complex recompression logic during replication

The assumption is: "Get the data across correctly first, optimize storage later with VACUUM"

## The Evidence in Your Data

Your numbers show the exact pattern:
- **Publisher**: 180 GB TOAST (properly compressed)
- **Subscriber**: 4566 GB TOAST (uncompressed - 25× larger)

The `table_percent` values confirm:
- **Publisher**: 0.27% in main table (99.73% efficiently TOASTed)
- **Subscriber**: 0.07% in main table (99.93% inefficiently TOASTed)

## This is "Working as Designed"

While frustrating, this is **expected behavior** in current PostgreSQL versions. The documentation mentions this indirectly by recommending alternative methods for large initial syncs.

The good news: **Once the initial sync is done, ongoing replication will handle TOAST correctly** because it works with the WAL log which contains the proper storage information.

This is why the PostgreSQL community recommends `pg_dump`/`pg_restore` for large initial syncs when TOASTable data is involved.
