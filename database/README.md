# SmartBiz AI — Database (Phase 3)

هذا المجلد يحتوي كل ما يخص PostgreSQL: 13 migration مرقّمة، ERD، وبيانات seed تجريبية.

## ما تم إنجازه

- ✅ 13 جدول (`companies` → `ai_logs`) مطابقة تمامًا لـ ERD المعتمد في Phase 1
- ✅ Multi-tenancy: `company_id` + فهرس على كل جدول عملياتي
- ✅ `unit_price`/`unit_cost` مُلتقطة (snapshot) في `sale_items` وقت البيع لحماية دقة الأرباح التاريخية
- ✅ Triggers تلقائية لتحديث `updated_at`
- ✅ Seed script ببيانات تجريبية مطابقة لأمثلة الـ Spec (Amine Grocery)
- ✅ `docker-compose.yml` لتشغيل PostgreSQL محليًا بأمر واحد (اختياري لكن موصى به)

## ⚠️ لم أستطع تشغيل هذه الـ migrations هنا

ليس لدي PostgreSQL في بيئة المحادثة هذه، لذلك **لم أُنفّذ الملفات فعليًا ولم أتحقق منها بـ `psql` حقيقي**. هي مكتوبة بعناية باتباع SQL/PostgreSQL syntax صحيح، لكن يجب أن تُشغّلها أنت على جهازك وتؤكد لي النتيجة (نفس منهج Test → Fix الذي اتبعناه في Phase 2).

---

## خطوات التنفيذ (بالتفصيل الذي طلبته)

### الخيار أ) عبر Docker (الأسهل والموصى به)

**1. ماذا أثبّت؟** Docker Desktop.
**2. من أين؟** https://www.docker.com/products/docker-desktop/
**3. هل أحتاج حسابًا؟** حساب Docker Hub مجاني اختياري فقط لتسجيل الدخول للتطبيق؛ ليس إلزاميًا للاستخدام الأساسي.
**4. أين أنشئه؟** https://hub.docker.com (إن رغبت).
**5. ما الذي أُعدّه؟** لا شيء إضافي — الملف `docker-compose.yml` جاهز بالكامل بمستخدم/كلمة مرور/اسم قاعدة بيانات محددة مسبقًا للتطوير المحلي فقط.
**6. أي ملف أعدّله؟** لا شيء، إلا إذا رغبت بتغيير `POSTGRES_PASSWORD`.
**7. ماذا أضع بداخله؟** لا شيء إضافي مطلوب.
**8. أي أمر أُشغّله؟**
```bash
cd database
docker compose up -d
```
**9. ما المخرج المتوقع؟** رسالة تفيد أن الحاوية `smartbiz_postgres` بدأت (`Started` أو `running`). تحقق بـ:
```bash
docker ps
```
يجب أن تظهر حاوية باسم `smartbiz_postgres` على المنفذ `5432`.
**10. كيف أتحقق؟** انتقل مباشرة لقسم "تشغيل الـ Migrations" أدناه.

---

### الخيار ب) تثبيت PostgreSQL مباشرة على الجهاز (بدون Docker)

**1. ماذا أثبّت؟** PostgreSQL (نسخة 15 أو 16).
**2. من أين؟** https://www.postgresql.org/download/ (اختر نظام تشغيلك).
**3. هل أحتاج حسابًا؟** لا.
**4. أين أنشئه؟** لا ينطبق.
**5. ما الذي أُعدّه؟** أثناء التثبيت، سيطلب منك تحديد كلمة مرور للمستخدم `postgres` — اخترها واحفظها.
**6. أي ملف أعدّله؟** لا شيء في هذه الخطوة.
**7. ماذا أضع بداخله؟** لا ينطبق.
**8. أي أمر أُشغّله؟** بعد التثبيت، أنشئ قاعدة البيانات:
```bash
createdb -U postgres smartbiz
```
(إن طُلبت كلمة مرور، أدخل التي اخترتها عند التثبيت.)
**9. ما المخرج المتوقع؟** لا رسالة = نجاح. للتأكد:
```bash
psql -U postgres -l
```
يجب أن تظهر `smartbiz` في القائمة.
**10. كيف أتحقق؟** انتقل لقسم "تشغيل الـ Migrations" أدناه.

---

## تشغيل الـ Migrations (بعد أي من الخيارين أعلاه)

من داخل مجلد `database/`, نفّذ الملفات **بالترتيب الرقمي** (000 ثم 001 ثم 002...):

### إذا استخدمت Docker:
```bash
for f in migrations/*.sql; do
  docker exec -i smartbiz_postgres psql -U smartbiz -d smartbiz < "$f"
done
```

### إذا ثبّتّ PostgreSQL مباشرة:
```bash
for f in migrations/*.sql; do
  psql -U postgres -d smartbiz -f "$f"
done
```

**ما المخرج المتوقع؟** لكل ملف، رسائل مثل `CREATE TABLE`, `CREATE INDEX`, `CREATE TRIGGER` بدون أي `ERROR`. إذا ظهر أي `ERROR`، انسخ الرسالة كاملة وأرسلها لي فورًا.

**كيف أتحقق أن كل الجداول أُنشئت؟**
```bash
# Docker:
docker exec -it smartbiz_postgres psql -U smartbiz -d smartbiz -c "\dt"

# تثبيت مباشر:
psql -U postgres -d smartbiz -c "\dt"
```
يجب أن تظهر قائمة بـ 13 جدولًا: `companies, users, employees, attendance_records, salary_adjustments, suppliers, customers, products, sales, sale_items, invoices, expenses, appointments, notifications, ai_logs`.

---

## تحميل بيانات Seed التجريبية (اختياري لكن موصى به للاختبار)

```bash
# Docker:
docker exec -i smartbiz_postgres psql -U smartbiz -d smartbiz < seeds/seed_dev_data.sql

# تثبيت مباشر:
psql -U postgres -d smartbiz -f seeds/seed_dev_data.sql
```

**تحقّق:**
```bash
psql -U postgres -d smartbiz -c "SELECT name, business_type FROM companies;"
```
يجب أن تظهر صف واحد: `Amine Grocery | grocery`.

```bash
psql -U postgres -d smartbiz -c "SELECT name, quantity FROM products WHERE company_id = (SELECT id FROM companies WHERE name = 'Amine Grocery');"
```
يجب أن تظهر 4 منتجات (Whole Milk 1L, Baguette Bread, Sugar 1kg, Olive Oil 1L) بنفس الكميات الظاهرة في أمثلة الـ Spec.

---

## هيكل الملفات

```
database/
├── migrations/
│   ├── 000_extensions_and_functions.sql
│   ├── 001_create_companies.sql
│   ├── 002_create_users.sql
│   ├── 003_create_employees.sql        # + attendance_records + salary_adjustments
│   ├── 004_create_suppliers.sql
│   ├── 005_create_customers.sql
│   ├── 006_create_products.sql
│   ├── 007_create_sales.sql            # + sale_items
│   ├── 008_create_invoices.sql
│   ├── 009_create_expenses.sql
│   ├── 010_create_appointments.sql
│   ├── 011_create_notifications.sql
│   └── 012_create_ai_logs.sql
├── seeds/
│   └── seed_dev_data.sql
├── docker-compose.yml
├── ERD.md
└── README.md   (هذا الملف)
```

---

## الخطوة التالية (بعد تأكيدك أن كل شيء يعمل)

**Phase 4: Flutter Application Features + Local/Data Layer** — ربط شاشات Flutter الموجودة (وبناء الباقي) بطبقة بيانات محلية (models + repositories)، تمهيدًا لربطها بالـ API الحقيقي في Phase 5.

بانتظار تأكيدك.
