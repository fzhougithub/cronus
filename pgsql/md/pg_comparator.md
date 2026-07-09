To compare two tables, `pg_comparator` uses a "Divide and Conquer" approach based on a Merkle Tree-like algorithm. It does not just compare the tables row-by-row; it builds a multi-level hierarchy of checksums to find differences efficiently.

Here are the exact steps it performs:

### Step 1: The Initial Scan (Checksum Table Creation)
The tool starts by scanning both tables in full. It executes a `CREATE TEMPORARY TABLE` on both sides (or both sessions within your single database). 
* It concatenates your **Key Columns** (`customer_id`, `claim_id`, `process_create_ts`) to create a **Key Checksum (`kcs`)**.
* It concatenates **All Columns** (or specific ones you chose) to create a **Tuple Checksum (`tcs`)**.
* **Result:** You now have two temporary tables (e.g., `pgc_cmp_1_0` and `pgc_cmp_2_0`) containing one row for every row in your original tables, but reduced to just hashes and the primary keys.



---

### Step 2: Building the Summary Tree (Folding)
This is where the tool gets its speed. It doesn't compare the millions of rows in the temp tables yet. Instead, it "folds" the data into multiple levels of summary tables:
* **Level 1 Summary:** It groups rows from the initial temp table (usually in chunks of 128, controlled by `--folding-factor`) and creates a single aggregate checksum for that group.
* **Higher Levels:** It repeats this process (Summary of Summary) until it reaches a "Root" level that contains only a few rows representing the entire table's state.



---

### Step 3: Top-Down Comparison (The Search)
Now the tool compares the two tables starting from the **top** (the root summary):
1. **Compare Roots:** If the top-level aggregate checksums match, the tables are identical, and it stops immediately.
2. **Drill Down:** If they don't match, it looks at the level below to see which specific "folder" or "chunk" caused the mismatch.
3. **Branching:** It only follows the branches of the tree where the checksums differ, ignoring the parts of the tables that are identical.

---

### Step 4: Leaf Level Identification
Once it drills down to the very bottom of the tree (the actual rows in your `pgc_cmp` temp tables):
* It identifies the specific `customer_id`, `claim_id`, and `process_create_ts` where the `tcs` (data hash) is different.
* It checks if the `kcs` (key hash) is missing from one side (Insert/Delete) or if the keys match but the data is different (Update).

---

### Step 5: Reporting
Finally, it prints the results to your terminal based on what it found at the leaf level:
* **`<`**: The row exists in the first table but is missing in the second.
* **`>`**: The row exists in the second table but is missing in the first.
* **`!`**: The row exists in both, but the data is different.

### Summary of Resource Usage
| Phase | Database Load | Network/Terminal Load |
| :--- | :--- | :--- |
| **Step 1** | **High** (Full Sequential Scan) | Low |
| **Step 2** | **Medium** (Aggregating Temp Tables) | Low |
| **Step 3/4** | **Low** (Index lookups on Temp Tables) | Low |
| **Step 5** | None | **High** (If millions of rows differ) |

