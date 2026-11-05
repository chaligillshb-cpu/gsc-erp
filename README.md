# Pesticide Shop ERP — Offline-first GitHub + Supabase build

A responsive browser ERP for a Pakistani pesticide/agricultural shop. The app stores working records in IndexedDB on each device and can synchronize them to an authenticated Supabase project when internet is available.

**Currency:** PKR / Rs.  
**Hosting:** GitHub Pages (static frontend)  
**Cloud identity and sync:** Supabase Auth + Postgres RPC + Row Level Security  
**Offline storage:** IndexedDB + PWA service worker

## Current modules in this codebase

- Dashboard with sales, collections, outstanding customer credit, inventory value, low-stock and expiry alerts
- Company directory
- Product catalogue with company, category, brand, pack, SKU, purchase/retail/wholesale prices, batch and expiry fields
- Opening stock and stock adjustment history
- Customer profiles, credit limits, balances and customer ledger
- POS invoice with multiple product lines, discount, partial payment, credit due, stock deduction and printable invoice
- Customer receipt recording
- Purchase entry and supplier payable balance
- Shop expenses
- Basic sales, estimated profit and inventory reports
- CSV sales export
- JSON backup and restore
- Supabase account creation/sign-in, shop creation, manager/assistant membership and cloud sync queue
- PWA installable app shell and offline local database

## Architecture and important behaviour

1. Each device has its own IndexedDB database. The app remains usable when offline after it has been loaded on that device.
2. Every local row create/update/delete is placed into an IndexedDB outbox.
3. When online and signed in, the app sends queued changes to Supabase RPCs, then pulls the shop's cloud records.
4. Cloud writes are idempotent per `(shop_id, table_name, record_id)`. Deletes are soft-deleted in the cloud.
5. The current conflict policy is **last successful sync wins per record**. It is suitable for initial controlled testing, but it is not a substitute for server-side transaction locking or a full conflict-resolution workflow.
6. Staff accounts must first sign up and verify their email. The owner can then add the account as a manager or assistant from Cloud Sync & Team.
7. Never put a Supabase service-role key in this frontend. Use only the public anon/publishable key; database RPCs apply membership and role checks.

## Deploy to GitHub Pages

1. Create a new GitHub repository.
2. Extract this ZIP and upload the **contents of the `pesticide-shop-erp` folder** to the repository root. Include the `.github` folder.
3. Commit to the `main` branch.
4. In GitHub, open **Settings → Pages** and choose **GitHub Actions** as the build/deployment source.
5. Open **Actions** and wait for `Deploy Pesticide Shop ERP to GitHub Pages` to succeed.
6. Open the published Pages URL. Use the browser's Install App option to install it on desktop or mobile.

## Create and configure Supabase

See [CLOUD_SETUP.md](CLOUD_SETUP.md) for the full walkthrough. In brief:

1. Create a Supabase project.
2. Open **SQL Editor** and run `supabase/schema.sql`.
3. Configure Email Auth and the project's Site URL / redirect URL.
4. In the app, open **Cloud Sync & Team**, enter the Supabase Project URL and public anon/publishable key, then save.
5. Create your owner account, verify email if required, and sign in.
6. Create your shop. The app queues local records and uploads them.
7. On the second device, open the same deployed app, configure the same Supabase project, sign in with the same account, and sync.
8. For staff: have each staff member create and verify their own account, then the owner adds their email and role.

## Run locally

From this folder:

```bash
python -m http.server 8000
```

Open `http://localhost:8000`. A service worker requires localhost or HTTPS; do not open `index.html` as a `file://` URL.

## Backup

Use **Settings & Backup → Download full backup** regularly. Store at least two copies in separate safe places. Cloud synchronization is not a backup by itself.

## Important release status — read before using for live accounting

This is an integrated offline/cloud **working foundation**, not yet a certified or production-audited ERP. The original specification is broader than the modules currently implemented. In particular, the following still need implementation and end-to-end verification before relying on this for the shop's official books:

- Normalized relational business tables and server-side transactional RPCs for sale, purchase, receipt, returns and stock movements. The current cloud replication layer stores the local app's rows in a protected sync envelope.
- Atomic server-side sale/purchase/payment posting, stock locking and duplicate-payment/idempotency keys at the business-transaction level.
- Complete sales returns, supplier returns, invoice cancellation/reversal and refund workflows.
- FEFO batch allocation, batch-level stock reconciliation and expiry/damaged-stock workflows.
- Supplier payment ledger and supplier statement.
- Full double-entry accounting, cash/bank accounts, reconciled trial balance and audited P&L.
- Assistant-specific customer assignment, permission editor, secure per-screen UI restrictions and owner audit-log viewer.
- Full report filters, PDF/Excel exports, A4/58mm/80mm invoice templates, charts and financial-year controls.
- Automated database backup/restore testing, migration tests, concurrency tests and a security review.

**Do not treat estimated profit or balances from this build as audited financial statements.** Test with dummy data first, verify backup restoration, and reconcile the results against your existing records before entering real transactions. For a live shop, have a developer complete the listed controls and review the Supabase SQL/RLS setup.
