# SQL guide — the offline bill cache

This is the learning companion to the offline cache. It explains every SQL
statement the app runs, one at a time, starting from what a table is. The
queries themselves live in
[`lib/features/bills/data/local/bill_queries.dart`](../lib/features/bills/data/local/bill_queries.dart);
this document repeats them with the explanation, the Dart call site and
practice tasks, so you can type them yourself against a real database.

Read §1–§6 in order. Do the tasks in §12 with the database open; the solutions
are at the end so you can check yourself.

---

## 0. Where the queries live

| Layer | File | What it knows |
|---|---|---|
| SQL text | `lib/features/bills/data/local/bill_queries.dart` | every hand-written statement, nothing else |
| Execution | `lib/features/bills/data/local/sqlite_bill_store.dart` | binds `?` values, groups rows, runs transactions |
| Schema | `lib/features/bills/data/local/bill_database.dart` | file name, version, `onCreate` / `onUpgrade`, pragma |
| Mapping | `lib/features/bills/data/local/bill_row_mapper.dart` | row ⇄ `Bill`, column names |
| Policy | `lib/features/bills/data/repositories/offline_bill_repository.dart` | when to read the cache, when to queue |

The SQL is kept out of the repository and out of the widgets on purpose:

- one file to read when you want to learn or change the queries;
- one file to diff when the schema changes;
- no page, bloc or repository has a `SELECT` hidden inside it.

> **Why not literally only in the doc?** The app has to execute the SQL to be
> offline. The compromise is that no statement is scattered through logic:
> `bill_queries.dart` is a flat catalogue, and this guide mirrors it
> query-for-query. Type a query here first, get it right in a scratch database,
> then copy it into the catalogue.

---

## 1. Why SQLite in this app

The bills dashboard has to show the last known bills when the phone is on a
train with no signal, and a bill saved in that tunnel must not be lost. That is
two problems:

1. **Read cache** — the last `GET /bills` response, stored on disk.
2. **Write queue** — a confirmed bill that the server has not accepted yet.

SQLite gives both with one file, no server, ACID transactions and indexed
queries. `sqflite` is the Flutter plugin that exposes it on Android, iOS and
macOS. (Web and Windows/Linux desktop have no sqflite implementation; in those
builds the app falls back to `MemoryBillStore`, so previews still work but do
not survive a restart.)

What it is **not** for: the access token (that is SharedPreferences today,
`flutter_secure_storage` in a production build) or large binary files (a photo
is sent, not stored).

---

## 2. SQL in ninety seconds

- A **table** is a grid with named **columns** and any number of **rows**.
- **`PRIMARY KEY`** uniquely identifies a row. The `bills` table uses the bill
  id (a server UUID or a temporary `local-…` id).
- **`FOREIGN KEY`** points at another table's primary key. `bill_items.bill_id`
  points at `bills.id`; `ON DELETE CASCADE` means deleting a bill deletes its
  lines.
- **`WHERE`** filters rows. **`ORDER BY`** sorts them. **`LIMIT`** caps them.
- **`JOIN`** combines two tables by matching a column on both sides.
- **`?`** is a parameter placeholder. The value is sent separately, never glued
  into the string, so quotes and SQL injection are not your problem.
- **A transaction** groups statements so either all of them happen or none do.
- An **index** is a sorted lookup structure; without one SQLite scans every row.

---

## 3. The flow these queries implement

**Opening the dashboard**

```
BillsStarted
  └─ fetchBills()
       ├─ readPending(owner)            → §5.3 + §5.4
       ├─ POST /bills/confirm × N       (one per queued bill)
       │    └─ promotePending()         → §6.5
       ├─ GET /bills
       │    └─ replaceServerBills()     → §6.4, §6.1, §6.2
       └─ readBills(owner)              → §5.1 + §5.2
```

If the network fails at `GET /bills`, the last two steps are skipped and the
cache from §5.1 is returned with `BillsSource.cache`; that is what turns on the
"Offline · showing saved bills" banner.

**Saving a reviewed bill**

```
POST /bills/confirm
  ├─ success → saveBill()               → §6.1 + §6.2
  └─ unreachable → saveBill(pending)    → §6.1 + §6.2  (local-… id)
```

A pending row is visible immediately (badge "Pending sync") and is sent on the
next successful read, then replaced by the server's row.

---

## 4. Schema — `BillQueries.createBillsTable` etc.

### 4.1 The `bills` table

```sql
CREATE TABLE bills (
  id TEXT PRIMARY KEY NOT NULL,
  owner_id TEXT NOT NULL,
  merchant TEXT NOT NULL,
  bill_date TEXT NOT NULL,
  total REAL NOT NULL,
  currency TEXT NOT NULL DEFAULT 'INR',
  category TEXT NOT NULL,
  icon TEXT,
  notes TEXT,
  round_off REAL,
  sync_status TEXT NOT NULL CHECK (sync_status IN ('synced', 'pending')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
```

Line by line:

| Column | Why |
|---|---|
| `id TEXT PRIMARY KEY` | Server id (`9f2…`) or a local id (`local-178…-1`) while queued. `TEXT` because the API returns UUID-ish strings. |
| `owner_id TEXT` | The signed-in user id, or `'guest'`. Every read filters on it so two accounts on one phone cannot see each other's cache. |
| `merchant TEXT NOT NULL` | Shop name. `NOT NULL` means the database itself rejects a missing value. |
| `bill_date TEXT` | `2026-10-01`. ISO dates sort correctly as text (`2026-10` < `2026-11`), so `ORDER BY` needs no parsing. |
| `total REAL` | Rupees with decimals. **Money as `REAL` is a known trade-off**: binary floating point cannot represent `0.10` exactly. For production accounting, store integer **paise** (`total_paise INTEGER`) instead. The app already uses `double` end to end, so this cache mirrors it. |
| `currency TEXT DEFAULT 'INR'` | Kept for a future multi-currency feature; the API accepts INR only today. |
| `category TEXT` | The API slug (`dining`, `transport`, …), not the display label. |
| `icon`, `notes`, `round_off` | Nullable; the printed round-off line is absent on most bills. |
| `sync_status TEXT CHECK (…)` | Only two values are legal. The `CHECK` is documentation the database enforces. |
| `created_at`, `updated_at` | ISO 8601 timestamps written by the app. `created_at` gives the queue a stable FIFO order and makes the file debuggable. |

### 4.2 The `bill_items` table

```sql
CREATE TABLE bill_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bill_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  name TEXT NOT NULL,
  amount REAL NOT NULL,
  quantity INTEGER,
  FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE
)
```

Why a second table instead of a JSON column?

- **Normalisation**: a bill has 0..N lines, and each line is a row. No parsing
  in Dart, no favourite-item search over JSON text.
- **Ordering**: `position` preserves the printed order (0, 1, 2…), which a
  `JOIN` alone would not guarantee.
- **Cascade**: deleting a bill removes its lines automatically.

`amount` is the **whole printed line**, not a unit price. That matches the API
and the review screen's copy.

### 4.3 Foreign keys need a pragma

```sql
PRAGMA foreign_keys = ON
```

SQLite disables foreign keys by default (a 2000s compatibility decision).
`BillDatabase._configure` runs this on every connection; without it,
`ON DELETE CASCADE` silently does nothing and orphan items pile up.

### 4.4 Indexes

```sql
CREATE INDEX idx_bills_owner_date ON bills (owner_id, bill_date DESC)
CREATE INDEX idx_bills_owner_sync ON bills (owner_id, sync_status)
CREATE INDEX idx_bill_items_bill ON bill_items (bill_id, position)
```

Read them as "a sorted copy of these columns". The first one serves
`WHERE owner_id = ? ORDER BY bill_date DESC` without sorting the table. The
second finds queued rows without scanning every bill. The third makes the items
join and its `ORDER BY` cheap.

---

## 5. Reading — `SELECT`

### 5.1 The list for one owner

`BillQueries.selectBillsForOwner`

```sql
SELECT id, owner_id, merchant, bill_date, total, currency, category,
       icon, notes, round_off, sync_status, created_at, updated_at
FROM bills
WHERE owner_id = ?
ORDER BY bill_date DESC, created_at DESC
```

How to read it:

1. `FROM bills` — start with this table.
2. `WHERE owner_id = ?` — keep only this account's rows. The `?` is filled by
   `readBills('7')`; SQLite looks at it as data, never as SQL.
3. `ORDER BY bill_date DESC` — newest bill first. A second key
   (`created_at DESC`) breaks ties when two bills share a date, because SQLite
   does not promise an order without one.
4. The column list is explicit instead of `SELECT *` so adding a column later
   cannot silently change a Dart map.

Dart side (`SqliteBillStore._read`) passes `[ownerId]` and maps each row with
`BillRowMapper.fromRow`.

**Try it**

```sql
SELECT merchant, total FROM bills WHERE owner_id = '7' ORDER BY bill_date DESC;
```

### 5.2 The items, in one query

`BillQueries.selectItemsForOwner`

```sql
SELECT i.bill_id, i.name, i.amount, i.quantity, i.position
FROM bill_items AS i
INNER JOIN bills AS b ON b.id = i.bill_id
WHERE b.owner_id = ?
ORDER BY i.bill_id, i.position
```

- `bill_items AS i` and `bills AS b` are aliases: shorter names for the rest of
  the statement.
- `INNER JOIN … ON b.id = i.bill_id` pairs every item with its bill. `INNER`
  means rows with no match are dropped; since the foreign key points at a real
  bill, every item matches.
- `WHERE b.owner_id = ?` filters on the **bill**, not the item — the item table
  has no `owner_id` of its own (that would duplicate data and risk it drifting).
- `ORDER BY i.bill_id, i.position` gives a deterministic printed order.

Why not one query per bill? That is the **N+1 problem**: 50 bills would mean 51
queries. One join + grouping in Dart is two queries total:

```dart
final Map<String, List<BillItem>> itemsByBill = {};
for (final row in itemRows) {
  itemsByBill.putIfAbsent(row['bill_id'], () => []).add(...);
}
```

**Try it**

```sql
SELECT b.merchant, i.name, i.amount
FROM bill_items AS i
JOIN bills AS b ON b.id = i.bill_id
ORDER BY b.bill_date DESC, i.position;
```

### 5.3 The upload queue

`BillQueries.selectPendingBillsForOwner`

```sql
SELECT id, owner_id, merchant, bill_date, total, currency, category,
       icon, notes, round_off, sync_status, created_at, updated_at
FROM bills
WHERE owner_id = ? AND sync_status = ?
ORDER BY created_at ASC
```

- `AND` adds a second condition; both must be true.
- The state is a **parameter** (`BillSyncState.pending.name` → `'pending'`)
  instead of the literal `'pending'`, so the enum and the database cannot drift.
- `created_at ASC` is FIFO: the oldest queued bill is confirmed first. That is
  what a person expects from a queue.

### 5.4 Items for the queue

`BillQueries.selectPendingItemsForOwner`

```sql
SELECT i.bill_id, i.name, i.amount, i.quantity, i.position
FROM bill_items AS i
INNER JOIN bills AS b ON b.id = i.bill_id
WHERE b.owner_id = ? AND b.sync_status = ?
ORDER BY i.bill_id, i.position
```

Same join as §5.2 with the queue filter. The store passes
`[ownerId, 'pending']` for both statements, so the bills and their items always
describe the same set.

### 5.5 Does this owner have any bills?

`BillQueries.countBillsForOwner`

```sql
SELECT COUNT(*) AS bill_count
FROM bills
WHERE owner_id = ?
```

`COUNT(*)` counts rows; `AS bill_count` names the result column so Dart can read
`row['bill_count']` instead of a positional index. `LocalBillRepository` uses it
to seed the demo bill exactly once for a guest.

---

## 6. Writing — `INSERT`, `DELETE`

### 6.1 Insert or replace a bill

The `INSERT` is built by sqflite's `insert` API, which produces the same
parameterised statement:

```sql
INSERT OR REPLACE INTO bills (
  id, owner_id, merchant, bill_date, total, currency, category,
  icon, notes, round_off, sync_status, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
```

`ConflictAlgorithm.replace` is the important part. It means: if a row with this
primary key exists, **delete it and insert this one**. That is how re-saving a
bill updates the cache.

Two cautions that come with it:

1. `REPLACE` deletes the old row, and with foreign keys on that **cascades to
   `bill_items`**. The store deletes and re-inserts the items in the same
   transaction, so they are not lost.
2. `ON CONFLICT (id) DO UPDATE` (a true upsert) is the modern alternative, but
   it needs SQLite 3.24+. Older Android releases ship an older SQLite, so
   `REPLACE` is the portable choice here.

### 6.2 Delete the old items first

`BillQueries.deleteItemsForBill`

```sql
DELETE FROM bill_items WHERE bill_id = ?
```

Before writing a bill's items, the store removes the previous ones. Without
this, re-saving a bill with two lines instead of three would leave the third
line behind.

**Transaction needed.** If the delete succeeds and the app dies before the
inserts, the bill has no lines. Inside a transaction, the delete is rolled back
too.

### 6.3 Delete one bill

`BillQueries.deleteBillById`

```sql
DELETE FROM bills WHERE id = ? AND owner_id = ?
```

Both keys are required: if two owners ever had a row with the same id, one
account's delete must not touch the other's data.

With foreign keys on, the matching `bill_items` rows go automatically.

### 6.4 Delete only the server-owned rows

`BillQueries.deleteSyncedBillsForOwner`

```sql
DELETE FROM bills
WHERE owner_id = ? AND sync_status = ?
```

This runs before the fresh `GET /bills` rows are inserted. Filtering on
`sync_status = 'synced'` is the whole offline design in one line: a bill that
has not reached the server is **not** client state to be thrown away by a
refresh.

### 6.5 Promote a queued bill

Two statements in one transaction (`SqliteBillStore.promotePending`):

```sql
-- 1. remove the temporary local row (its items cascade)
DELETE FROM bills WHERE id = ? AND owner_id = ?;

-- 2. insert the server's version
INSERT OR REPLACE INTO bills (…) VALUES (…);
INSERT INTO bill_items (bill_id, position, name, amount, quantity) VALUES (?, ?, ?, ?, ?);
```

The local id is a placeholder. After the server accepts the bill, the real id
replaces it; showing both would double-count the spend on the dashboard.

---

## 7. Transactions

The store wraps multi-row writes in `database.transaction((txn) async { … })`.
Examples: saving a bill plus its items, replacing the cache, promoting a queued
bill.

Why:

- **Atomicity** — a reader never sees half a bill.
- **Speed** — SQLite commits to disk once per transaction instead of once per
  statement.
- **Rollback** — a thrown exception undoes every write inside the block.

The rule of thumb used in this code: if a bill row and its item rows must agree,
they belong in one transaction.

---

## 8. Indexes, measured

Run these in a scratch database after inserting a few bills:

```sql
EXPLAIN QUERY PLAN
SELECT id FROM bills WHERE owner_id = '7' ORDER BY bill_date DESC;
```

With `idx_bills_owner_date` you should see `SEARCH bills USING INDEX …` and no
`USE TEMP B-TREE FOR ORDER BY`. Drop the index (`DROP INDEX
idx_bills_owner_date`) and run it again: the plan turns into a full `SCAN` plus
a temporary sort. Put the index back.

Indexes cost storage and a little write time. Three small ones are a good
trade for a screen that opens on every app launch; a fourth would need a query
that actually uses it.

---

## 9. Migrations

`BillDatabase.schemaVersion` is `1`. On first install, `onCreate` runs; on later
installs, `onUpgrade` runs only when the stored version is lower than the code's
version.

**Never edit `_create` after release.** Existing phones never run it again, so
their schema would drift from new installs.

To add a column (example: `payment_method`):

1. bump `schemaVersion` to `2`;
2. add a step in `_upgrade`, guarded by the old version;
3. update the schema constant for new installs and the row mapper.

```dart
static Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute(
      "ALTER TABLE bills ADD COLUMN payment_method TEXT",
    );
  }
}
```

Rules:

- `ALTER TABLE … ADD COLUMN` cannot add a `NOT NULL` column without a default.
- Steps run in order, so a phone jumping from 1 to 3 runs both guards.
- Backfills go in the same step (`UPDATE bills SET payment_method = 'cash'`).
- Test the migration with `openDatabase(version: 1, …)`, close, then reopen with
  the new version and assert the column exists.
- A destructive change (rename/type change) needs the 12-step table rebuild:
  create `bills_new`, copy rows, drop `bills`, rename. SQLite has no
  `ALTER COLUMN`.

---

## 10. Running queries yourself

### 10.1 The fastest loop: a scratch test

`sqflite_common_ffi` runs real SQLite in a Dart VM test, no phone needed. Add a
file like this under `test/` and replace the query:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bill_scanner/features/bills/data/local/bill_database.dart';
import 'package:bill_scanner/features/bills/data/local/sqlite_bill_store.dart';

void main() {
  sqfliteFfiInit();

  test('scratch', () async {
    final db = await BillDatabase.open(
      factory: databaseFactoryFfi,
      filePath: inMemoryDatabasePath,
    );

    // Seed with the real store so the schema and mapper are exercised.
    final store = SqliteBillStore(db.database);
    // await store.saveBill('7', bill); // build a Bill in the test

    final rows = await db.database.rawQuery('''
      SELECT … -- your query here
    ''', <Object?>['7']);

    // ignore: avoid_print
    print(rows);
    await db.close();
  });
}
```

Run it with `flutter test test/your_file_test.dart -r expanded`.

Why this is better than guessing in production: same schema, same pragmas,
instant feedback, and the test can be deleted afterwards.

### 10.2 The real phone database

Debug builds are debuggable, so you can copy the file out:

```bash
adb shell run-as com.example.bill_scanner ls databases
adb exec-out run-as com.example.bill_scanner cat databases/bill_scan.db > bill_scan.db
```

Open `bill_scan.db` with [DB Browser for SQLite](https://sqlitebrowser.org/) or
`sqlite3 bill_scan.db`, then run §5.1. (`run-as` only works for a debuggable
build; check the `applicationId` in `android/app/build.gradle.kts`.)

On iOS, use Xcode's Devices window → Download Container → `AppData/Library/…`.

### 10.3 Useful SQLite shell commands

```text
.tables
.schema bills
.headers on
.mode column
PRAGMA foreign_keys;          -- 1 when the schema was opened by the app
PRAGMA table_info(bills);
```

---

## 11. Debugging checklist

| Symptom | Likely cause | Check |
|---|---|---|
| Items disappear when a bill is deleted | foreign keys off | `PRAGMA foreign_keys;` must be `1`; it is set in `BillDatabase._configure` |
| Cache refresh wiped an unsynced bill | refresh deleted all rows | `deleteSyncedBillsForOwner` must filter `sync_status` (see §6.4) |
| A bill appears twice | queue promoted without deleting the local row | `promotePending` is one transaction: delete local, insert server (§6.5) |
| Duplicate items after an edit | items not cleared first | `deleteItemsForBill` before the inserts (§6.2) |
| Dates sort in the wrong order | stored in a locale format | store ISO `yyyy-MM-dd` only |
| Dashboard slow with many bills | missing index | `EXPLAIN QUERY PLAN` (§8) |
| `UNIQUE constraint failed` on insert | `REPLACE` replaced by plain `INSERT` | keep `ConflictAlgorithm.replace` |
| Two accounts see the same bills | a read without `owner_id` | every statement starts with `WHERE owner_id = ?` |

---

## 12. Practice

Work in a scratch database (see §10.1). Solutions are in §13.

**1. List a shop's bills.** Return `merchant`, `bill_date`, `total` for bills
whose merchant is `Asha Tiffins`, newest first.

**2. Total per category.** For owner `'7'`, return `category` and the sum of
`total`, biggest spend first. *(Hint: `GROUP BY`, `SUM`, `AS`.)*

**3. This month's spend.** Sum the `total` of owner `'7'` bills whose
`bill_date` starts with `'2026-10'`. *(Hint: `LIKE '2026-10%'` or
`substr(bill_date, 1, 7) = ?`.)*

**4. Bills with no lines.** Return every bill that has zero `bill_items`.
*(Hint: `LEFT JOIN` + `IS NULL`, or `NOT EXISTS`.)*

**5. The full queue.** Return the pending bills for owner `'7'` with their items
in one result set, oldest queued first. *(Hint: join + `ORDER BY created_at`.)*

**6. A safe search.** Find bills whose merchant contains `'s'`, case-insensitive,
without breaking on an apostrophe. *(Hint: `LIKE ?` with `%s%`; never concatenate
the search term into SQL.)*

**7. Counts per day.** Return `bill_date` and the number of bills for the last
seven days. *(Hint: `GROUP BY bill_date`.)*

**8. Promote in a transaction.** Write the two statements that replace
`local-1` with server bill `9f2a` for owner `'7'` atomically.

**9. A migration.** Write the SQL to add a nullable `payment_method TEXT` column
and backfill every existing row with `'cash'`.

**10. Break it on purpose.** Drop `idx_bills_owner_date`, run
`EXPLAIN QUERY PLAN` on §5.1, then recreate the index. Note the plan before and
after.

---

## 13. Solutions

**1.**

```sql
SELECT merchant, bill_date, total
FROM bills
WHERE merchant = 'Asha Tiffins'
ORDER BY bill_date DESC;
```

**2.**

```sql
SELECT category, SUM(total) AS spent
FROM bills
WHERE owner_id = '7'
GROUP BY category
ORDER BY spent DESC;
```

**3.**

```sql
SELECT SUM(total) AS spent
FROM bills
WHERE owner_id = '7' AND bill_date LIKE '2026-10%';
```

**4.**

```sql
SELECT b.id, b.merchant
FROM bills AS b
LEFT JOIN bill_items AS i ON i.bill_id = b.id
WHERE i.id IS NULL;
```

**5.**

```sql
SELECT b.id, b.created_at, i.name, i.amount
FROM bills AS b
LEFT JOIN bill_items AS i ON i.bill_id = b.id
WHERE b.owner_id = '7' AND b.sync_status = 'pending'
ORDER BY b.created_at ASC, i.position ASC;
```

**6.**

```sql
SELECT id, merchant
FROM bills
WHERE merchant LIKE ? COLLATE NOCASE;
-- bind '%s%'
```

**7.**

```sql
SELECT bill_date, COUNT(*) AS bills
FROM bills
WHERE owner_id = '7' AND bill_date >= '2026-10-20'
GROUP BY bill_date
ORDER BY bill_date;
```

**8.**

```sql
BEGIN;
DELETE FROM bills WHERE id = 'local-1' AND owner_id = '7';
INSERT OR REPLACE INTO bills (id, owner_id, merchant, bill_date, total,
  currency, category, sync_status, created_at, updated_at)
VALUES ('9f2a', '7', 'Chai Point', '2026-10-22', 120.0,
  'INR', 'dining', 'synced', '2026-10-26T09:00:00', '2026-10-26T09:00:00');
COMMIT;
```

(In Dart the first statement is `rawDelete(deleteBillById, …)` and the second is
`insert(..., conflictAlgorithm: ConflictAlgorithm.replace)` inside
`database.transaction`.)

**9.**

```sql
ALTER TABLE bills ADD COLUMN payment_method TEXT;
UPDATE bills SET payment_method = 'cash';
```

**10.** Before: `SCAN bills` + `USE TEMP B-TREE FOR ORDER BY`. After:
`SEARCH bills USING INDEX idx_bills_owner_date (owner_id=?)`. The index removes
both the scan and the sort.

---

## 14. Interview questions this guide prepares you for

**Why SQLite rather than SharedPreferences or a JSON file?**
Queries, indexes and transactions. SharedPreferences is a key/value store: the
dashboard and its filters would become a full file read plus Dart filtering, and
a save queue would have no atomic swap.

**How do you handle a save while offline?**
The repository tries `POST /bills/confirm`. Only a connection/timeout failure is
queued, because a 422 will fail again forever. The queued row gets a `local-…`
id and `sync_status = 'pending'`, is shown with a badge, and the next successful
read flushes it and swaps in the server's row.

**What about getting a duplicate bill if the request reached the server but the
response was lost?** Known limitation: `POST /bills/confirm` has no idempotency
key, so a retry can create a second expense. The fix is server-side: accept a
client-generated `request_id` with a unique index, and let a retry return the
existing row. The app already has a stable local id it could send.

**How do you keep two accounts' caches apart?**
Every row has `owner_id`; every read and delete filters on it. The repository
reads the current user id at call time, so signing in or out re-partitions
without rebuilding the object graph.

**Why store the items in a second table?**
One-to-many rows, printed order via `position`, `ON DELETE CASCADE`, and no JSON
parsing. The cost is a join, which §5.2 handles in one query.

**How would you scale this?**
Cursor pagination (`WHERE bill_date < ? ORDER BY bill_date DESC LIMIT 50`), a
`bill_items` search index if item search grows, and moving the queue to a
WorkManager/managed background task so it flushes without opening the app.

**What would you change in the schema?**
Money to integer paise, and a `server_updated_at` column plus a last-write-wins
rule (or a proper conflict UI) for edits made on two devices.

**How is the cache tested?**
Two levels: the repository against an in-memory `BillLocalStore` (queue, cache
fallback, failure policy), and the SQL against real SQLite through
`sqflite_common_ffi` — schema, ordering, owner partitioning, cascade, promotion.
The widget tests then check the banner, the pending badge and an offline save at
320, 390 and 800 px.
