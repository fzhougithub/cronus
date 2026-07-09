Because **swap is not a guarantee against OOM**.

Many PostgreSQL DBAs assume:

```text
RAM 256G
Swap 64G

=> OOM should never happen
```

but Linux doesn't work that way.

---

### 1. OOM can happen before swap is exhausted

The kernel OOM killer triggers when it cannot satisfy a memory allocation request.

Not when:

```text
Swap Used = Swap Total
```

For example:

```text
RAM 256G
Swap 64G

Used RAM = 255G
Used Swap = 20G
```

A backend suddenly requests:

```text
+8G
```

If the kernel cannot free/reclaim pages quickly enough, it may invoke OOM immediately.

---

### 2. PostgreSQL often allocates memory in large chunks

Particularly relevant to your Hydra investigations.

A backend may suddenly ask for:

```text
1 GB
4 GB
8 GB
20 GB
```

for:

* HashAgg
* Hash Join
* Parallel workers
* Columnar decompression
* Hydra caches
* Custom extension memory contexts

The kernel needs contiguous virtual memory structures and reclaimable pages.

Swap doesn't magically satisfy every request.

---

### 3. Pages in D-state cannot be reclaimed

You've seen this yourself.

Hydra queries sometimes end up:

```text
D
Uninterruptible sleep
```

waiting on I/O.

Those pages may be:

```text
dirty
under writeback
locked
```

and are not immediately reclaimable.

The kernel may conclude:

```text
Need memory now
Cannot reclaim enough
OOM
```

even with swap available.

---

### 4. vm.overcommit settings

Check:

```bash
cat /proc/sys/vm/overcommit_memory
cat /proc/sys/vm/overcommit_ratio
```

If:

```text
vm.overcommit_memory = 2
```

Linux performs strict accounting.

Then a process may fail allocation or trigger OOM even when:

```text
free RAM exists
swap exists
```

because the committed memory limit was exceeded.

Check:

```bash
grep -E 'CommitLimit|Committed_AS' /proc/meminfo
```

---

### 5. cgroups / systemd limits

This catches people all the time.

Even if system memory is:

```text
RAM 340G
Swap 64G
```

PostgreSQL service may have:

```text
MemoryMax=300G
```

or container limits.

Then OOM occurs inside the cgroup.

Check:

```bash
systemctl show postgresql | grep Memory
```

or

```bash
cat /sys/fs/cgroup/memory.max
```

depending on OS version.

---

### 6. Swap may be intentionally avoided

Check:

```bash
sysctl vm.swappiness
```

Many DB servers use:

```text
vm.swappiness = 1
```

or

```text
vm.swappiness = 0
```

to avoid swapping PostgreSQL pages.

Then Linux prefers:

```text
reclaim cache
OOM
```

instead of aggressively swapping.

---

### 7. The Hydra-specific possibility

From your earlier observations:

* backend memory keeps growing
* `DISCARD ALL` doesn't release it
* only connection exit releases memory
* kill -9 sometimes destabilizes PostgreSQL
* huge columnar scans

This suggests memory may be sitting in:

```text
backend private memory
Hydra caches
extension memory contexts
```

If several backends each consume tens of GB:

```text
10 backends × 30G
```

you can exhaust memory faster than the kernel can swap.

---

### What I would check after an OOM

Look at:

```bash
dmesg -T | grep -A20 -B5 -i oom
```

or

```bash
journalctl -k | grep -i oom
```

The kernel will tell you:

```text
Out of memory:
Killed process 12345 (postgres)
total-vm: ...
anon-rss: ...
file-rss: ...
```

That output is gold because it tells:

1. Which postgres PID got killed.
2. How much memory it was using.
3. Whether it was RSS, anonymous memory, cache, etc.

For your Hydra environment, I'd be especially interested in the OOM log because it often reveals whether:

```text
one giant backend
```

or

```text
many medium-sized backends
```

caused the kill. Those lead to very different solutions.

