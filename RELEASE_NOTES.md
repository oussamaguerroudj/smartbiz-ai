# Modiri AI — Release Notes

## v0.1.0 (2026-10-06)

Production release of **Modiri AI** (`v0.1.0`), consolidating backend API, multi-tenant business management, offline-first synchronization, AI/OCR invoice scanning, and comprehensive security hardening.

### Security
- **Authentication & Session Hardening**: Restricted JWT verification to `HS256` with strict access/refresh token type separation, enforced distinct 32+ character secrets, and added cryptographically random OTP generation with attempt lockouts.
- **Authorization & RBAC**: Enforced owner-only role checks across employee management, payroll/salary payments, salary expense creation/modification, and AI runtime configuration endpoints (both REST and batch sync).
- **Multi-Tenancy Isolation**: Scoped PostgreSQL queries and foreign-key ownership checks by authenticated `companyId`, and enforced `company_id` tenant scoping across all local SQLite tables and repositories.
- **AI & SSRF Protection**: Restricted AI configuration and inference calls to validated local/configured inference hosts and ports, blocking loopback/link-local/metadata SSRF vectors and URL credential/query injection.
- **File Storage Security**: Added magic-byte signature validation (`PDF`, `JPEG`, `PNG`, `WebP`), strict path-traversal rejection, tenant-isolated storage namespaces, `X-Content-Type-Options: nosniff`, and sanitized `Content-Disposition` headers.
- **Resource & Abuse Protection**: Added sliding-window rate limiting for authentication, OTP verification, and global API routes, bounded offline sync batch sizes, and enforced upload size limits on API and OCR microservices.

### Offline-First & Synchronization
- Local SQLite persistence (`modiri_offline_v1.db`) supporting products, sales, sale items, invoices, expenses, customers, employees, suppliers, appointments, restaurant orders/tables, and idempotent `sync_queue` batching.
- Preserved unsynced local tenant data across account switches while maintaining strict cross-account isolation.

### Business Modules & Financial Engine
- Unified margin-based financial and inventory valuation across backend and local offline calculators.
- Full support for Superette/Retail, Restaurant (dine-in, takeaway, delivery workflows, multi-cart POS), Pharmacy, Clinic, Clothing, and Enterprise business profiles.
- Complete Arabic (`ar`), French (`fr`), and English (`en`) localization coverage and responsive UI layouts verified across compact screen dimensions.

### AI & OCR Pipeline
- Self-hosted open-source Qwen/GLM-OCR invoice scanning pipeline with deterministic state transitions, preflight health checks, vision fallback, and editable sale price with unit margin calculation.

### Testing & Verification
- **Backend**: 15 test suites, 183/183 automated tests passing (including security audit, multi-tenant isolation, financial calculations, restaurant order lifecycle, and OCR pipeline).
- **Mobile (Flutter)**: 101/101 automated widget and unit tests passing, `flutter analyze` passing with 0 issues.
