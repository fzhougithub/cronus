| Code | Meaning                                                              | Example value            |
| ---- | -------------------------------------------------------------------- | ------------------------ |
| `%d` | **Failed node ID** (integer, like `0`, `1`, `2`)                     | `1`                      |
| `%h` | **Failed node hostname**                                             | `pgdb02`                 |
| `%p` | **Failed node port**                                                 | `5432`                   |
| `%D` | **Failed node data directory**                                       | `/var/lib/pgsql/17/data` |
| `%m` | **New master node ID** (after failover)                              | `0`                      |
| `%H` | **New master node hostname**                                         | `pgdb01`                 |
| `%M` | **New master node port**                                             | `5432`                   |
| `%P` | **Old primary node ID** (before failover)                            | `0`                      |
| `%r` | **Remote host of client connected to Pgpool when failover happened** | `10.2.34.56`             |
| `%R` | **Port number of that remote client**                                | `60742`                  |
| `%N` | **Failed node’s name** (the one defined in `backend_hostnameN`)      | `backend1`               |
| `%t` | **Timestamp** when failover occurred                                 | `2025-10-06 23:03:44`    |
| `%n` | **Number of backend nodes** (total count)                            | `2`                      |

