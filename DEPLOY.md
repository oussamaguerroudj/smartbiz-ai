# Modiri AI — Deployment & Operation Manual

## 1. Overview & Architecture

Modiri AI is a multi-tenant business management and point-of-sale platform comprising:
- **Backend API**: Node.js 18+ / Express / PostgreSQL 16.
- **Mobile Client**: Flutter cross-platform client with Riverpod state management.
- **Tenant Isolation**: Multi-tenant isolation enforced at the JWT, route, and PostgreSQL database queries (`WHERE company_id = $1`).
- **Option A Onboarding**: Registration collects credentials (`name`, `email`, `password`); email verification creates the company with `business_type = NULL` and `onboarding_completed = false`; Business Type selection and setup explicitly commits the business type and marks `onboarding_completed = true`.

---

## 2. Deploying Your Own Backend on Render

The repository includes a ready-to-deploy Render Blueprint specification in [`render.yaml`](file:///c:/Users/Haoui/Downloads/modiri-business-type-simplified%20%281%29/render.yaml).

### Step 2.1: Connect Repository to Render
1. Log in to your Render Dashboard at [https://dashboard.render.com](https://dashboard.render.com).
2. Click **New +** and select **Blueprint**.
3. Connect your GitHub repository (`smartbiz-ai` or your fork).
4. Select the branch containing this deployment (e.g. `main` after merging `fix/own-backend-deploy`).
5. Render will automatically parse [`render.yaml`](file:///c:/Users/Haoui/Downloads/modiri-business-type-simplified%20%281%29/render.yaml) and declare two resources:
   - **smartbiz-db**: Managed PostgreSQL instance (free tier).
   - **smartbiz-ai-backend**: Node.js web service running the Express API.

### Step 2.2: Configure Mandatory Environment Variables
In the Render Blueprint configuration interface, you must provide values for the sync-disabled SMTP environment variables:

| Variable Name | Description | Example Value |
|---|---|---|
| `SMTP_HOST` | Hostname of your SMTP email provider | `smtp.mailgun.org` or `smtp.resend.com` |
| `SMTP_PORT` | Port for TLS/STARTTLS SMTP submission | `587` (or `465`) |
| `SMTP_USER` | SMTP username or API key | `postmaster@yourdomain.com` |
| `SMTP_PASS` | SMTP password or secret API key | `your-secret-smtp-password` |
| `SMTP_FROM` | Sender email address displayed to users | `no-reply@yourdomain.com` |

> [!IMPORTANT]
> The backend server enforces **fail-fast boot validation** in production (`NODE_ENV=production`). If any of the five SMTP variables are missing, the server process will exit with code 1 at boot to prevent users registering without receiving verification emails.

> [!WARNING]
> **Render Free Tier Outbound SMTP Restriction**:
> Render blocks outbound traffic on SMTP ports 25, 465, and 587 for all web services on the Free tier. When running on Render Free tier, direct SMTP connections to `smtp-relay.brevo.com:587` will hang until client timeout. Upgrading the Render web service to any paid instance type (e.g. Starter) unblocks outbound ports 587 and 465. Alternatively, port 2525 can be evaluated if permitted by the network tier.
>
> **Brevo Sender Verification**:
> `SMTP_FROM` must match an authorized/verified sender address in Brevo (e.g. `oussama.guerroudj@ensia.edu.dz`). Unverified sender addresses will cause Brevo to reject or block transactional email dispatch.

### Step 2.3: Automated Migrations & Tracking Table
Render executes the following startup command automatically:
```bash
node run_migrations.js && node src/server.js
```
- Migrations are tracked in the `schema_migrations` PostgreSQL table.
- Each migration file in `backend/migrations/` is executed exactly once in ascending numerical order inside an atomic transaction.
- If any migration fails, the runner halts with code 1, preventing corrupted startup.

### Step 2.4: Health Check Endpoint
Once deployed, Render monitors the service health via:
```
GET /api/health
```
Expected response:
```json
{
  "status": "ok",
  "env": "production"
}
```

---

## 3. Database Safety & Email Normalization

### Read-Only Duplicate Email Audit Queries
Before running in production or after restoring a legacy database, execute these read-only queries in your PostgreSQL database (e.g., via Render PostgreSQL query console or psql) to detect any un-normalized duplicates:

```sql
-- Check for casing or whitespace duplicate accounts in users:
SELECT lower(trim(email)) AS normalized_email, count(*) AS occurrences
FROM users
GROUP BY lower(trim(email))
HAVING count(*) > 1;

-- Check for casing or whitespace duplicate entries in pending registrations:
SELECT lower(trim(email)) AS normalized_email, count(*) AS occurrences
FROM pending_registrations
GROUP BY lower(trim(email))
HAVING count(*) > 1;
```

> [!NOTE]
> Migration `032_normalize_emails_and_unique_indexes.sql` creates a unique expression index `idx_users_email_unique_lower` on `lower(trim(email))`. If duplicates exist, the migration will abort cleanly without deleting or merging data.

### Reviewing and Flagging Legacy Placeholder Companies (Manual Step)
Legacy versions of the backend created companies with placeholder `name = 'New Business'` and `business_type = 'company'`.
To guarantee safety on existing production databases, this update is NOT in the automatic startup sequence. It is located in [`backend/manual_migrations/034_flag_placeholder_companies.sql`](file:///c:/Users/Haoui/Downloads/modiri-business-type-simplified%20%281%29/backend/manual_migrations/034_flag_placeholder_companies.sql).

**What it does to "company" accounts**:
When applied, any legacy placeholder company (`name = 'New Business'` AND `business_type = 'company'`) has its `business_type` set to `NULL` and `onboarding_completed` set to `false`. When users belonging to these accounts subsequently log in or refresh tokens, the API reports `onboardingCompleted: false` and `businessType: null`, prompting the mobile application to route them directly to the Business Type Setup screen so they can choose their real industry and business model rather than remaining stuck with a dummy company profile.

1. Execute the read-only query to inspect matching rows:
```sql
SELECT id, name, business_type, onboarding_completed, created_at
FROM companies
WHERE name = 'New Business' AND business_type = 'company';
```
2. If confirmed, execute the manual update script:
```sql
UPDATE companies
SET onboarding_completed = false,
    business_type = NULL
WHERE name = 'New Business'
  AND business_type = 'company';
```
Or apply the file directly via psql:
```bash
psql $DATABASE_URL -f backend/manual_migrations/034_flag_placeholder_companies.sql
```

---

## 4. Security Posture & Accepted Operational Decisions

### 4.1 CORS_ORIGIN = "*" (Temporary Accepted Decision)
`CORS_ORIGIN` is configured to `"*"` in [`render.yaml`](file:///c:/Users/Haoui/Downloads/modiri-business-type-simplified%20%281%29/render.yaml). This is a **temporary accepted decision** for the initial rollout:
- The current client ecosystem consists solely of native mobile applications (Android/iOS Flutter client). Native HTTP clients do not send browser `Origin` headers and do not enforce the browser Same-Origin Policy.
- Once a web dashboard or administrative web application is deployed, `CORS_ORIGIN` must be restricted in the Render environment settings to the specific production web origins (e.g. `https://admin.yourdomain.com`).

### 4.2 Nodemailer High Severity Advisory (Accepted Risk)
`npm audit --omit=dev` reports 0 critical vulnerabilities. All critical vulnerabilities in transitive dependencies (`proxy-addr`, `tar`, `qs`) were remediated.
One high-severity advisory remains on `nodemailer <= 10.0.5` ([GHSA-mm7p-fcc7-pg87](https://github.com/advisories/GHSA-mm7p-fcc7-pg87)):
- Remediating this advisory requires upgrading across a major breaking change boundary to `nodemailer@10.x`.
- In Modiri AI, `nodemailer` is strictly used server-side with verified SMTP credentials to send short 6-digit OTP verification codes to user-provided email addresses (`sendVerificationEmail` / `sendPasswordResetEmail`). It does not accept arbitrary untrusted MIME structures or client-provided transport configurations.
- Therefore, this advisory is documented and classified as an **accepted risk** until a planned major version refactor of the email transport layer.

---

## 5. Building & Running the Flutter Client

The Flutter application requires the API URL to be supplied at compile time via `--dart-define=API_URL`. Hardcoded third-party backend URLs have been eliminated.

### Step 5.1: Development Run
To test against your Render backend:
```bash
cd mobile
flutter run --dart-define=API_URL=https://<your-render-service>.onrender.com/api
```

To test locally against a local backend:
```bash
cd mobile
flutter run --dart-define=API_URL=http://10.0.2.2:4000/api   # Android Emulator
# or
flutter run --dart-define=API_URL=http://localhost:4000/api  # iOS Simulator / Desktop / Web
```

### Step 5.2: Production Release APK Build
Build the release APK with the production API URL:
```bash
cd mobile
flutter build apk --release --dart-define=API_URL=https://<your-render-service>.onrender.com/api
```
The resulting APK is generated at:
`mobile/build/app/outputs/flutter-apk/app-release.apk`

> [!WARNING]
> If a release APK is built without `--dart-define=API_URL`, the application displays a user-visible configuration guard screen blocking execution rather than sending requests to an undefined or unconfigured endpoint.

---

## 6. Physical Device Smoke Test Script (QA Checklist)

Follow this step-by-step checklist on a real physical device (Android or iOS) running the newly built release APK:

### Phase 1: Clean Startup & Registration
- [ ] **Step 1.1**: Install the release APK on a physical device. Launch the application.
- [ ] **Step 1.2**: Proceed past Language Selection and Onboarding carousel to the **Register** screen.
- [ ] **Step 1.3**: Verify that the Register form displays ONLY:
  - Full Name
  - Email Address
  - Password (with eye toggle)
  - Confirm Password (with eye toggle)
  - *(Confirm NO Industry or Business Type dropdown exists)*.
- [ ] **Step 1.4**: Fill out the form with a new email address (e.g. `test.device@yourdomain.com`) and tap **Create Account**.
- [ ] **Step 1.5**: Verify the app transitions immediately to the **Verify Account** screen displaying a 6-digit OTP input.

### Phase 2: Email Verification & Option A Onboarding
- [ ] **Step 2.1**: Check your email inbox for the 6-digit verification code.
- [ ] **Step 2.2**: Enter the code into the verification screen.
- [ ] **Step 2.3**: Verify the app authenticates the session and **routes directly to the Business Type Selection Screen** (Option A onboarding).
- [ ] **Step 2.4**: Verify the app does **NOT** display the Enterprise / General Company dashboard.

### Phase 3: Business Type Setup & Tailored Dashboard
- [ ] **Step 3.1**: Select your business type (e.g. **Supermarket & Grocery** or **Retail Store**).
- [ ] **Step 3.2**: Enter business details (Business Name, Currency, Address) and tap **Finish Setup**.
- [ ] **Step 3.3**: Verify the app transitions to the tailored dashboard matching the selected type (e.g., `SuperetteMainDashboardScreen` for Grocery).

### Phase 4: Session Persistence & Re-Authentication
- [ ] **Step 4.1**: Navigate to the **More** tab and tap **Log Out**.
- [ ] **Step 4.2**: Re-enter your credentials on the **Login** screen and tap **Sign In**.
- [ ] **Step 4.3**: Verify that the app logs in and navigates **directly to your tailored dashboard**, without showing the Business Type screen again.

### Phase 5: Core Business Operations
- [ ] **Step 5.1**: Navigate to **Products** and tap **Add Product**. Create a product (Name: `Test Product 1`, Price: `150`, Stock: `50`). Verify the product appears in the list.
- [ ] **Step 5.2**: Navigate to **Customers** and create a customer.
- [ ] **Step 5.3**: Navigate to **Sales / POS** and complete a sale. Verify that inventory decrements and an invoice is generated.
- [ ] **Step 5.4**: Navigate to **Expenses** and record an operational expense. Verify the total updates.
