### Creating an Encapsulated Package for pg_duckdb on AlmaLinux 9

Since pg_duckdb uses a custom Makefile (not standard PGXS), it doesn't have built-in targets for packaging like `dist` or RPM generation. However, you can create either an RPM (native for AlmaLinux) or a tarball distributable after running `make` (which builds the extension and DuckDB) but before `make install` (which deploys to the system). This avoids server-by-server builds.

I'll outline both options below. The RPM approach is recommended for AlmaLinux as it handles dependencies, versioning, and easy deployment via `dnf`. The tarball is simpler but requires manual extraction and `make install` on targets.

#### Prerequisites
- Complete Steps 1-4 from the previous guide up to `make PG_CONFIG=/usr/pgsql-16/bin/pg_config` (this builds everything in the source directory).
- Install RPM build tools (if not already done):
  ```
  sudo dnf install -y rpm-build redhat-rpm-config
  ```
- Set up RPM build directories (as a non-root user):
  ```
  mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
  echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
  ```

#### Option 1: Create an RPM Package (Recommended)
To package the built extension into an RPM, we'll use `rpmbuild` with a custom spec file. This captures the built artifacts (e.g., the shared library, SQL/control files) and installs them correctly on target servers (e.g., to PostgreSQL's extension dir).

1. **Prepare the Source Tarball**:
   After `make`, create a tarball of the built source (this acts as the "source" for RPM):
   ```
   git archive --format=tar.gz --prefix=pg_duckdb/ -o ~/rpmbuild/SOURCES/pg_duckdb-built.tar.gz HEAD
   tar -rf ~/rpmbuild/SOURCES/pg_duckdb-built.tar.gz --transform 's|^pg_duckdb/|pg_duckdb-built/|' pg_duckdb/
   ```
   - This includes your built files (e.g., `pg_duckdb.so` in the build dir).

2. **Create a Spec File**:
   Create `~/rpmbuild/SPECS/pg_duckdb.spec` with the following content (adjust version/release as needed; this assumes PG 16):
   ```
   Name:           pg_duckdb
   Version:        0.10.2  # Replace with actual DuckDB/pg_duckdb version (check via git describe or README)
   Release:        1%{?dist}
   Summary:        DuckDB-powered PostgreSQL extension for analytics

   License:        MIT
   URL:            https://github.com/duckdb/pg_duckdb
   Source0:        %{name}-built.tar.gz

   BuildRequires:  postgresql16-devel, gcc-c++, cmake, ninja-build
   Requires:       postgresql16-server

   %description
   pg_duckdb embeds DuckDB's analytical engine into PostgreSQL for high-performance queries.

   %prep
   %setup -q -n %{name}-built

   %build
   # Already built; skip to ensure artifacts are used
   make duckdb PG_CONFIG=%{_bindir}/pg_config

   %install
   PG_CONFIG=%{_bindir}/pg_config make install DESTDIR=%{buildroot}

   %files
   %defattr(-,root,root,-)
   %{_libdir}/pgsql/pg_duckdb.so
   %{pgextensiondir}/pg_duckdb*
   %{pgsharedir}/extension/pg_duckdb*

   %changelog
   * Wed Oct 29 2025 Your Name <you@example.com> - 0.10.2-1
   - Built pg_duckdb for AlmaLinux 9 / PG 16
   ```
   - **Key Notes**:
     - `%files`: Lists installed files (e.g., `.so` library, `.control`, `.sql`). Run `make install DESTDIR=/tmp/staging` first to inspect and adjust paths if needed (e.g., `/usr/pgsql-16/share/extension/`).
     - Version: Run `git describe --tags` in the repo to get the exact version.
     - For multi-PG support, add conditionals (e.g., via `%if` for PG 15/16).

3. **Build the RPM**:
   ```
   rpmbuild -ba ~/rpmbuild/SPECS/pg_duckdb.spec
   ```
   - Output: `~/rpmbuild/RPMS/x86_64/pg_duckdb-*.rpm` (binary RPM) and `~/rpmbuild/SRPMS/*.src.rpm` (source RPM).
   - If errors occur (e.g., missing deps), install them via `dnf` (e.g., `sudo dnf install libicu-devel`).

4. **Test and Distribute**:
   - Install on a test server: `sudo dnf localinstall ~/rpmbuild/RPMS/x86_64/pg_duckdb-*.rpm`.
   - This runs the `%install` section, placing files correctly. Then follow Step 5 from the original guide (add to `shared_preload_libraries` and `CREATE EXTENSION`).
   - For a private repo, host the RPM on a web server and add to `/etc/yum.repos.d/`.

#### Option 2: Create a Tarball (Simpler, No RPM Tools Needed)
This bundles the source with built artifacts for easy extraction and `make install` on targets.

1. **After `make`, Create the Tarball**:
   ```
   tar -czf pg_duckdb-built.tar.gz --transform 's|^./|pg_duckdb/|' pg_duckdb/ duckdb/ Makefile README.md  # Include key files
   ```
   - This creates `pg_duckdb-built.tar.gz` with the entire built repo.

2. **Distribute and Install on Targets**:
   - Copy the tarball to servers.
   - Extract: `tar -xzf pg_duckdb-built.tar.gz`.
   - Run: `make PG_CONFIG=/usr/pgsql-16/bin/pg_config install` (as before).
   - For automation, include a script (`install.sh` in the tarball):
     ```
     #!/bin/bash
     PG_VER=16
     PG_CONFIG=/usr/pgsql-${PG_VER}/bin/pg_config
     make PG_CONFIG=${PG_CONFIG} install
     echo "shared_preload_libraries = 'pg_duckdb'" | sudo tee -a /var/lib/pgsql/${PG_VER}/data/postgresql.conf
     sudo systemctl restart postgresql-${PG_VER}
     ```

#### Troubleshooting
- **Build Errors in RPM**: If `make install DESTDIR=...` fails, ensure `DESTDIR` is supported (test manually). Adjust spec `%install` to copy files explicitly (e.g., `cp pg_duckdb.so $RPM_BUILD_ROOT%{_libdir}/pgsql/`).
- **Version Mismatch**: Use `make duckdb` again in `%build` if needed.
- **Size Issues**: DuckDB is large (~100MB); the RPM/tarball will reflect this.
- **Pre-Built RPMs**: Check third-party repos like Pigsty (pigsty.io) for pg_duckdb RPMs, or build once and reuse.

This process encapsulates the build once on a build server, then deploys via RPM/tarball. For advanced RPMs (e.g., with post-install scripts for `shared_preload_libraries`), extend the spec file. Refer to [Fedora RPM Packaging Guidelines](https://docs.fedoraproject.org/en-US/packaging-guidelines/) for more. If you need a sample spec tweaked for your version, provide the output of `git describe`.
