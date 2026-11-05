# Changelog

## Offline-first cloud sync build
- Added Supabase email/password authentication UI.
- Added owner shop creation and manager/assistant membership RPCs.
- Added IndexedDB sync outbox and soft-delete replication.
- Added automatic sync attempts after local changes and when connectivity returns.
- Added role-aware server sync restrictions and redaction for selected assistant data.
- Added Supabase SQL setup and GitHub Pages deployment instructions.
- Kept the existing local shop workflows and JSON backup/restore.


## GSC customer-product history update
- Branded the interface and invoice default as Gill Spray Centre (GSC).
- Added customer purchase-history view: product-wise totals, quantities, purchase dates, invoices and line-item detail.
- Added product buyer lookup: customers who purchased a selected product, quantities, sales totals and last purchase date.
- These reports are derived from saved sales invoice line items; historical purchases entered outside this app will not appear unless imported/recorded.
