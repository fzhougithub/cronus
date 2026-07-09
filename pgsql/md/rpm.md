That's a great question! The `rpm -q` (query) command is very powerful and has many options beyond `-ql` to help you get detailed information about packages and manage your system.

Here are some of the most useful `rpm -q` options, grouped by what they help you discover:

### To Get More Information About a Package

| Option | Command Structure | Description | Example |
| :--- | :--- | :--- | :--- |
| **-i** | `rpm -qi package_name` | **Display package information.** Shows name, version, release, size, build date, install date, vendor, summary, and a full description. | `rpm -qi bash` |
| **-l** | `rpm -ql package_name` | **List all files** in the installed package (you already know this one). | `rpm -ql httpd` |
| **-c** | `rpm -qc package_name` | List only the **configuration files** in the package. | `rpm -qc ssh` |
| **-d** | `rpm -qd package_name` | List only the **documentation files** (man pages, READMEs, etc.) in the package. | `rpm -qd coreutils` |
| **-s** | `rpm -qs package_name` | **Display the state of all files** in the package (e.g., normal, not installed, replaced). Useful for verifying file integrity. | `rpm -qs systemd` |
| **--scripts** | `rpm -q --scripts package_name` | Display the **installation and uninstallation scripts** that run before/after a package is installed/removed. | `rpm -q --scripts mariadb-server` |
| **--provides** | `rpm -q --provides package_name` | List the **capabilities** (virtual packages, files, etc.) that the package provides. | `rpm -q --provides kernel` |
| **-R** or **--requires** | `rpm -qR package_name` | List the **dependencies** (capabilities or packages) that this package requires to be installed. | `rpm -qR firefox` |

### To Query by Other Criteria

| Option | Command Structure | Description | Example |
| :--- | :--- | :--- | :--- |
| **-a** | `rpm -qa` | **Query *all* installed packages.** This is often piped to `grep` for searching. | `rpm -qa \| grep mysql` |
| **-f** | `rpm -qf /path/to/file` | Query the package that **owns the specified file**. Essential for figuring out where a file came from. | `rpm -qf /etc/fstab` |
| **-p** | `rpm -qp package_file.rpm` | Query the information from an **uninstalled package file** (`.rpm` file), without installing it. Works with all the info options above (`-qip`, `-qlp`, etc.). | `rpm -qip new_app.rpm` |
| **--whatprovides** | `rpm -q --whatprovides capability` | Query packages that **provide a specific capability** (which could be a package name, a file, or a virtual dependency). | `rpm -q --whatprovides /bin/sh` |
| **--whatrequires** | `rpm -q --whatrequires capability` | Query packages that **require a specific capability** or package. | `rpm -q --whatrequires perl` |

### General Management and Verification

| Option | Command Structure | Description | Example |
| :--- | :--- | :--- | :--- |
| **-V** or **--verify** | `rpm -V package_name` | **Verify the integrity** of the installed package's files. It checks file size, MD5 checksum, permissions, type, owner, and group against the RPM database records. | `rpm -V httpd` |

By combining the main **Querying Options** (`-q`, `-qa`, `-qf`, `-qp`, etc.) with the **Information Selection Options** (`-i`, `-l`, `-c`, `-d`, `-R`, etc.), you can get almost any detail you need about the RPM packages on your system.
