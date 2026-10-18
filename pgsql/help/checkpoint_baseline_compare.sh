-- Run during/after a quiet period with no known batch jobs active,
-- to get a baseline checkpoint buffer count for comparison against
-- the 1,932,259 / 1,088,957 buffers seen in the spike window.
SELECT
    checkpoints_timed,
    checkpoints_req,
    checkpoint_write_time,
    checkpoint_sync_time,
    buffers_checkpoint,
    buffers_clean,
    buffers_backend,
    stats_reset
FROM pg_stat_bgwriter;
