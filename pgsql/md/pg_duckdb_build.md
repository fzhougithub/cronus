### Prerequisites
Before building `pg_duckdb` (a PostgreSQL extension that embeds DuckDB's analytical engine), ensure you have:
- A running AlmaLinux 9 system with root or sudo access.
- At least 2-4 GB of free disk space (building DuckDB takes time and space).
- PostgreSQL 16 installed (recommended for compatibility; pg_duckdb has been tested with it). If you have a different version, adjust package names accordingly.

### Step 1: Update the System
Update your package manager to ensure all dependencies are current:
```
sudo dnf update -y
```

### Step 2: Install PostgreSQL 16
AlmaLinux's default repos may not have the latest PostgreSQL. Add the official PostgreSQL repository and install it:

1. Install the repo RPM:
   ```
   sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
   ```

2. Disable the built-in PostgreSQL module (to avoid conflicts):
   ```
   sudo dnf -qy module disable postgresql
   ```

3. Install PostgreSQL 16 server and client:
   ```
   sudo dnf install -y postgresql16 postgresql16-server
   ```

4. Initialize the database (if not auto-initialized):
   ```
   sudo /usr/pgsql-16/bin/postgresql-16-setup initdb
   ```

5. Start and enable the service:
   ```
   sudo systemctl start postgresql-16
   sudo systemctl enable postgresql-16
   ```

6. (Optional) Set a password for the `postgres` superuser:
   ```
   sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'your_secure_password';"
   ```

### Step 3: Install Build Dependencies
pg_duckdb requires DuckDB to be built as part of the process, so install the necessary tools and libraries. These are adapted for AlmaLinux 9 (RHEL-based) from DuckDB's official build instructions:

```
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y git gcc-c++ cmake ninja-build openssl-devel readline-devel zlib-devel flex bison libxml2-devel libxslt-devel libxml2 libxslt pkgconfig glibc-devel libstdc++-devel lz4-devel libicu-devel postgresql16-devel
```

- `postgresql16-devel`: Provides `pg_config` and headers like `postgres.h` (essential for building extensions).
- The rest are for compiling DuckDB and pg_duckdb (e.g., `cmake` and `ninja-build` for faster builds).

If you encounter missing packages (e.g., for a different PG version), search with `dnf search <package>`.

### Step 4: Clone and Build pg_duckdb
1. Clone the repository:
   ```
   git clone https://github.com/duckdb/pg_duckdb.git
   cd pg_duckdb
   ```

2. Update submodules (DuckDB is included as a submodule):
   ```
   git submodule update --init --recursive
   ```

3. Build DuckDB first (this compiles the embedded DuckDB library; it may take 15-30 minutes):
   ```
   make duckdb
   ```

4. Build and install pg_duckdb (specify the path to `pg_config` for your PostgreSQL version):
   ```
   make PG_CONFIG=/usr/pgsql-16/bin/pg_config
   sudo make PG_CONFIG=/usr/pgsql-16/bin/pg_config install
   ```

   - If using a different PG version (e.g., 15), replace `16` with `15` and adjust `PG_CONFIG` accordingly (e.g., `/usr/pgsql-15/bin/pg_config`).
   - For a static DuckDB build (smaller binary), add `DUCKDB_BUILD=ReleaseStatic` to the make commands.

5. Clean up if needed (removes build artifacts but keeps DuckDB):
   ```
   make clean
   ```

### Step 5: Configure and Load the Extension
1. Edit PostgreSQL's configuration to preload the extension (required for pg_duckdb):
   - Add to `postgresql.conf` (usually at `/var/lib/pgsql/16/data/postgresql.conf`):
     ```
     shared_preload_libraries = 'pg_duckdb'
     ```
   - You can append this via:
     ```
     echo "shared_preload_libraries = 'pg_duckdb'" | sudo tee -a /var/lib/pgsql/16/data/postgresql.conf
     ```

2. Restart PostgreSQL:
   ```
   sudo systemctl restart postgresql-16
   ```

3. Connect to PostgreSQL and create the extension:
   ```
   sudo -u postgres psql
   ```
   Inside psql:
   ```
   CREATE EXTENSION pg_duckdb;
   \q
   ```

### Step 6: Verify Installation
Connect to psql again (`sudo -u postgres psql`) and test:
```
SET duckdb.force_execution = true;
SELECT version();
```
- This should show DuckDB's version integrated into PostgreSQL.
- For analytics queries, try a sample: `SELECT COUNT(*) FROM your_table;` (replace with a real table).

### Troubleshooting
- **"postgres.h: No such file or directory"**: Ensure `postgresql16-devel` is installed and `PG_CONFIG` points to the correct path (`which pg_config` to verify).
- **Build fails on Python**: pg_duckdb doesn't require Python; if it appears, skip with `-DBUILD_PYTHON=0` in CMake (but default build avoids this).
- **Permission errors**: Run as a non-root user for cloning, but use `sudo` for installation.
- **Older PG version**: pg_duckdb is tested on PG 16; for PG 15 or 17, check compatibility in the [GitHub issues](https://github.com/duckdb/pg_duckdb/issues).
- **Long build time**: Use `ninja` for parallelism (default in the Makefile).

For more details, refer to the [official compilation docs](https://github.com/duckdb/pg_duckdb/blob/main/docs/compilation.md). If using Docker, consider the official `pgduckdb/pgduckdb` image for testing.
