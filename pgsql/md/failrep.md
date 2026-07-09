Perfect question 👍 — this is the **guts of logical replication** that explain why you see things like `substate = 'f'`. Let’s walk step by step.

---

## 🔹 1. `pg_subscription_rel.srsubstate` values

In PostgreSQL **14**, each table in a subscription has a state machine. The column `pg_subscription_rel.srsubstate` tracks it:

| Value   | Meaning          | What happens                                                                                          |
| ------- | ---------------- | ----------------------------------------------------------------------------------------------------- |
| **`i`** | **initialize**   | Table is scheduled to start synchronization. Worker will create initial sync slot.                    |
| **`d`** | **data copy**    | Initial data copy is running (a copy worker is reading from publisher via `COPY`).                    |
| **`s`** | **synchronized** | Initial data copy finished, apply worker will start catching up with WAL stream.                      |
| **`r`** | **ready**        | Table is fully replicated and kept in sync. Normal apply worker applies incoming changes.             |
| **`f`** | **failed**       | Something went wrong (permission, network, slot invalidation, etc). Worker stops until you intervene. |

👉 In PG15+, more states exist (like `u = unknown`) but the core ones are `i → d → s → r` (or `f` if it fails).

---

## 🔹 2. Process lifecycle (what talks to what)

Logical replication uses **multiple worker processes** on the subscriber:

1. **Launcher** (bgworker):

   * Starts subscription workers.
   * One subscription = one **apply worker**.

2. **Apply worker** (on subscriber):

   * Connects to publisher using `libpq` (with `primary_conninfo`).
   * Creates/maintains the replication slot on publisher (`pg_replication_slots`).
   * Spawns **table sync workers** if needed.

3. **Table sync worker(s)** (only for initial load):

   * Runs `COPY (SELECT …)` on publisher.
   * Inserts rows into subscriber.
   * When finished, tells apply worker it’s done → state goes `s`.

---

## 🔹 3. Back-and-forth communication

Here’s the **state transition handshake** between publisher and subscriber:

1. **Init (`i`)**

   * Subscriber’s apply worker records table as `i`.
   * Creates a **temporary replication slot** on publisher for that table.

2. **Data copy (`d`)**

   * Subscriber launches sync worker.
   * Sync worker sends `COPY (SELECT * FROM table)` to publisher.
   * Publisher streams all rows → subscriber inserts them.

3. **Catch up (`s`)**

   * Sync worker replays *missed changes* from WAL (via replication slot).
   * Once fully caught up, sync worker stops.
   * Apply worker takes over.

4. **Ready (`r`)**

   * Apply worker keeps applying changes continuously.
   * Only WAL changes are exchanged now.

5. **Failure (`f`)**

   * If data copy breaks (permissions, disk space, slot invalidation, etc) → state `f`.
   * Subscription does not retry automatically in PG14 — you must reset or refresh.

---

## 🔹 4. Why this matters for you

* If a table is stuck in `f`, it means the **sync worker** failed.
* Common causes:

  * No `SELECT` on publisher table.
  * No `INSERT` on subscriber table.
  * Slot invalidated (publisher `wal_keep_size` too small, so slot fell behind).
  * Network issue during initial copy.

To fix in PG14:

```sql
-- Reset failed table to retry sync
UPDATE pg_subscription_rel
SET srsubstate = 'i'
WHERE srrelid = 'schema.table'::regclass
  AND srsubid = (SELECT oid FROM pg_subscription WHERE subname = 'your_sub');

-- Then restart subscription
ALTER SUBSCRIPTION your_sub REFRESH PUBLICATION;
```

---

✅ So: **the substate is an internal state machine** managed by apply/sync workers.

* Publisher streams rows + WAL → subscriber receives, updates `srsubstate`.
* If anything breaks → `f` and waits for DBA action.

---

Would you like me to draw you a **diagram (timeline style)** showing how the messages flow (`COPY`, `WAL`, ACKs) between publisher and subscriber as the state transitions `i → d → s → r`?

