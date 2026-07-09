import sys
import polars as pl
import time

output_path = '/pg_backups/claim_citus.parquet'
log_path = '/pg_logs/claim_citus.log'

start_time = time.time()

try:
    with open(log_path, 'w') as log:
        log.write(f"[{time.ctime()}] Script started\n")

    df = pl.read_csv(sys.stdin)
    df.write_parquet(output_path)

    with open(log_path, 'a') as log:
        log.write(f"[{time.ctime()}] Finished writing {df.shape[0]} rows to {output_path}\n")

except Exception as e:
    with open(log_path, 'a') as log:
        log.write(f"[{time.ctime()}] ERROR: {str(e)}\n")

