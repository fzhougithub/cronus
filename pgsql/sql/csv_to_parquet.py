import sys
import time
import traceback
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from pandas.errors import EmptyDataError

output_path = '/pg_backups/claim_citus.parquet'
log_path = '/pg_logs/claim_citus.log'
chunk_size = 10000
row_count = 0

try:
    with open(log_path, 'w') as log:
        log.write(f"[{time.ctime()}] Script started\n")

    chunks = pd.read_csv(sys.stdin, chunksize=chunk_size)
    writer = None

    with open(log_path, 'a') as log:
        for i, chunk in enumerate(chunks):
            chunk = chunk.astype(str)  # Normalize types
            table = pa.Table.from_pandas(chunk)
            if writer is None:
                writer = pq.ParquetWriter(output_path, table.schema)
                log.write(f"[{time.ctime()}] Writer initialized\n")
            writer.write_table(table)
            row_count += len(chunk)
            log.write(f"[{time.ctime()}] Wrote chunk {i+1}, total rows: {row_count}\n")
            log.flush()

        if writer:
            writer.close()
            log.write(f"[{time.ctime()}] Finished writing {row_count} rows\n")

except EmptyDataError:
    with open(log_path, 'a') as log:
        log.write(f"[{time.ctime()}] ERROR: No data received on stdin\n")
    sys.exit(1)

except Exception as e:
    with open(log_path, 'a') as log:
        log.write(f"[{time.ctime()}] ERROR: {str(e)}\n")
        log.write(traceback.format_exc())
    sys.exit(2)

