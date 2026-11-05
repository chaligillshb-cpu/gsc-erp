# Cloud setup: Supabase + GitHub Pages

This is a one-time setup for the owner, then a short setup on each device.

## A. Create the Supabase project

1. Open https://supabase.com and create a project.
2. Choose a strong database password and keep it somewhere private.
3. Wait until the project finishes provisioning.
4. Open **Project Settings → API** (or API Keys).
5. Copy the Project URL and the public anon / publishable key.
6. Do **not** copy or expose the `service_role` / secret key.

## B. Create the database objects

1. In the Supabase project, open **SQL Editor**.
2. Create a new query.
3. Copy the full contents of `supabase/schema.sql` into the editor.
4. Run it and confirm the query completes successfully.

The script creates shops, shop membership, cloud sync records, audit events and security-definer RPCs. The browser does not receive direct table access to the sync payload tables; it uses the checked RPC functions.

## C. Configure email authentication

1. Open **Authentication → Providers → Email**.
2. Enable email/password sign-in.
3. Decide whether to require email confirmation. Requiring it is recommended.
4. Open **Authentication → URL Configuration**.
5. Set the Site URL to your deployed GitHub Pages URL, for example `https://YOUR-GITHUB-USERNAME.github.io/YOUR-REPOSITORY/`.
6. Add that exact URL to the allowed redirect URLs if required by your Supabase configuration.

## D. Deploy the app

Follow the GitHub Pages instructions in `README.md`. The deployed site must use HTTPS for PWA installation and service-worker operation.

## E. Connect the owner device

1. Open the deployed app on the laptop.
2. Open **Cloud Sync & Team** in the sidebar.
3. Paste the Supabase Project URL and public anon/publishable key.
4. Click **Save connection**.
5. Create an account with the owner's email and a strong password.
6. If email confirmation is enabled, open the confirmation email and verify the account.
7. Return to the app and sign in.
8. Enter the shop name and click **Create new shop**.
9. Wait for the first sync to finish.

## F. Connect the mobile device

1. Open the same GitHub Pages URL in Chrome/Safari on the phone.
2. Install/add the app to the home screen if desired.
3. Open **Cloud Sync & Team**.
4. Enter the same Supabase URL and public key.
5. Sign in with the same owner account.
6. Press **Sync now** once. The local device will download the shop's cloud records.
7. Keep the app open while the initial download completes.

Each device has its own offline database. Changes made offline on one device are uploaded when it reconnects and syncs. Do not edit the same record on two offline devices at the same time; the current per-record conflict policy is last successful sync wins.

## G. Add assistants and managers

1. Ask the staff member to create their own account from the app's **Cloud Sync & Team → Create account** screen.
2. If email confirmation is enabled, they must verify their email.
3. The owner signs in and opens **Cloud Sync & Team**.
4. Enter the staff member's verified email.
5. Choose Assistant or Manager and click **Add team member**.
6. The staff member configures the same Supabase project on their device and signs in.
7. They should then click **Sync now**.

The SQL sync API blocks assistant writes to selected sensitive record types and strips purchase-cost fields from assistant sync responses. This is not a complete permission editor; review the release limitations in README before using staff accounts with real business data.

## H. Verify the sync before live use

Use dummy data and test:

1. Add a company and product on the laptop.
2. Sync.
3. Sign in on mobile and verify the company/product appear.
4. Turn mobile internet off; create a test customer and test sale.
5. Turn internet back on and wait for sync.
6. Verify the customer, invoice, stock change and payment on the laptop.
7. Make a JSON backup from Settings & Backup and test restoring it in a separate browser profile.

If any values do not reconcile, stop and do not use the system for live transactions until the issue is fixed.

## Security notes

- GitHub Pages serves public frontend code. Never put passwords, service-role keys or private secrets in the repository.
- The anon/publishable key is public by design; Supabase RLS and RPC authorization are the security boundary.
- Use a unique password and email account for each staff member.
- Remove team membership promptly when a staff member leaves.
- Use a private device profile for the owner account.
- Download regular JSON backups. Supabase's own database backup options depend on the plan and are configured separately.
