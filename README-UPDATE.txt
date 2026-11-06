GSC ERP UPDATE — 06 NOV 2026

This is an incremental update for the existing Gill Spray Centre ERP.
It does not require a new Supabase project or a new shop. Do not delete existing Supabase rows.

Files to replace/add in the existing GitHub repository root:
- Replace: index.html, app.js, cloud.js, styles.css, sw.js
- Add: qrcode.js, QR_LICENSE.txt
- CHANGELOG.md is included as an optional documentation update.

After uploading and committing these files, open the existing GitHub Pages URL and press Ctrl+F5. The service worker cache was versioned to v3 so the new files can load.

New features:
- Correct ledger calculation: full sale total is debit; receipts are credits.
- Code 39 product barcode label and auto-generated product code if SKU/barcode is blank.
- Barcode entry for POS sale and purchase stock-in; barcode search in product catalogue.
- Camera scanning where supported by the browser's BarcodeDetector API. If unsupported, use a USB/Bluetooth scanner or type the barcode.
- Unique invoice QR code and invoice detail view. QR opens the exact invoice after the owner signs in and the cloud sync retrieves it.
- More polished invoice printout with GSC address and named contact numbers.

Important:
- This update changes frontend files only; no Supabase SQL migration is required.
- Keep using the same owner login, Supabase URL, publishable key, and existing shop.
- Do not enter real business records until the ledger, stock, invoice, barcode, backup and multi-device tests are completed.
- The invoice QR link uses the deployed app URL; test it on the live GitHub Pages site, not a localhost URL.
