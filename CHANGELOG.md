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

## GSC ledger, barcode and invoice update
- Corrected customer ledger sale debit to use the full invoice total, then credit receipts separately (e.g. Rs. 240 sale less Rs. 100 received = Rs. 140 running balance).
- Added Code 39 barcode labels, automatic SKU/barcode generation when a new product has no code, and manual/handheld scanner entry in stock catalogue, POS sales and purchase receiving.
- Added mobile camera scanning where the browser supports the BarcodeDetector API; manual/USB/Bluetooth scanner entry remains available as fallback.
- Added unique invoice QR codes to invoice printouts and invoice detail previews. QR links open the matching invoice after the owner app session has synced the record.
- Redesigned printed invoice with GSC branding, itemized totals, paid/due amounts, shop address and two named mobile contacts.
- Added editable contact/address fields in Shop Settings with the requested GSC address and contacts as defaults.
