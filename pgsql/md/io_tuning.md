Excellent question — this is where PostgreSQL tuning meets OS-level performance, and it’s critical if you’re dealing with heavy I/O, SAN storage, or large shared_buffers.

Below is a practical, production-grade guide to tuning OS page write performance so PostgreSQL benefits from faster, more efficient flushing of dirty pages.

🎯 Goal

Help the OS absorb and flush dirty pages faster, so:

• PostgreSQL backends don’t block

- bgwriter/checkpointer run smoothly
• SAN and disks aren’t overwhelmed

✅ 1. Tune OS Dirty Page Behavior (Linux)

PostgreSQL writes to the OS page cache, not directly to disk.  
Linux controls when and how those pages are flushed.

🔧 Key Kernel Parameters (/etc/sysctl.conf)

vm.dirty_ratio = 10
vm.dirty_background_ratio = 5


Or in bytes (recommended for large RAM):
vm.dirty_bytes = 1G
vm.dirty_background_bytes = 256M


📌 Meaning

Parameter Effect

dirty_background_* Start background flush

dirty_* Force processes to write

✅ Lower values = smoother flushing  
✅ Higher values = bursts, risk of latency spikes

✅ Recommended for PostgreSQL + SAN

vm.dirty_background_bytes = 268435456   # 256MB
vm.dirty_bytes = 1073741824             # 1GB


Then apply:
sysctl -p


✅ 2. I/O Scheduler (Critical for SAN)

Check current scheduler:
cat /sys/block/*/queue/scheduler


✅ Best Choice for SAN / NVMe

none


or for older kernels:
mq-deadline


🔧 Set at runtime:

echo none > /sys/block/sdX/queue/scheduler


✅ Reduces unnecessary reordering  
✅ Lets SAN handle I/O optimization

✅ 3. Filesystem Tuning

✅ Best choices:

• XFS (recommended)

• ext4 (acceptable)

Mount options (high-performance):

noatime,nodiratime,discard


Example:
/dev/mapper/san-data  /pgdata  xfs  noatime,nodiratime,discard  0  0


✅ Avoid data=journal on ext4  
✅ Avoid excessive sync

✅ 4. Disable or Reduce fsync Pressure (Carefully)

PostgreSQL already calls fsync() when needed.

❌ Do NOT:

• Disable fsync in PostgreSQL

• Use data=writeback blindly

✅ Do:

• Tune OS flushing (above)

• Use battery-backed SAN cache

• Use write-back cache if safe

✅ 5. Increase nr_requests (Queue Depth)

cat /sys/block/sdX/queue/nr_requests


Increase:
echo 1024 > /sys/block/sdX/queue/nr_requests


✅ Helps SAN absorb bursts  
✅ Especially useful with multipath

✅ 6. Multipath Tuning (If Using SAN)

Check:
multipath -ll


Tune:
/etc/multipath.conf


✅ Round-robin or queue-length policy  
✅ Increase pg_timeout  
✅ Enable queue_size

✅ 7. Monitor OS Write Behavior

🔍 Check dirty pages:

cat /proc/meminfo | grep Dirty


🔍 I/O pressure:

sar -d 1 10
iostat -x 1


🔍 PostgreSQL impact:

SELECT buffers_backend, buffers_clean
FROM pg_stat_bgwriter;


🚀 Summary Cheatsheet

Layer Tune

OS flushing vm.dirty_*

I/O scheduler none / mq-deadline

Filesystem xfs + noatime

Queue depth nr_requests

Multipath queue length

PostgreSQL bgwriter + checkpoint

✅ Final Verdict

“How can we tune OS-level page write performance?”

✅ Yes — and you absolutely should
✅ OS tuning often matters more than PostgreSQL tuning
✅ Critical for SAN, NVMe, high-throughput workloads

If you want, I can:
• give you exact values for your RAM & SAN

• help you build a tuning audit checklist

• show how OS tuning affects pg_stat_bgwriter

Just tell me 👍
