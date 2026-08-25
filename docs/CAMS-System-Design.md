# CAMS — Communication Asset Management System
## เอกสารออกแบบระบบ (System Design Document)

**หน่วยงาน:** ศูนย์ประสานงานการค้นหาและช่วยเหลืออากาศยานและเรือประสบภัย กองทัพอากาศ (RTAF RCC)
**สถานะ:** UI Prototype Phase — ยังไม่เริ่มพัฒนา backend จริง
**ขอบเขตการใช้งาน:** ระบบภายใน / intranet เท่านั้น ไม่เชื่อมต่อ cloud หรือ external API ใดๆ

> หมายเหตุ: ชื่อสถานะ, terminology เอกสารราชการ, ลำดับชั้นการอนุมัติ และผู้มีอำนาจอนุมัติในเอกสารนี้ **ยังไม่ใช่ข้อสรุปสุดท้าย** — รอการตรวจทานจากระเบียบ ทอ. ที่เกี่ยวข้อง ออกแบบให้ปรับค่าได้ (configurable) ไว้ก่อน ไม่ hardcode

---

## 1. ภาพรวมระบบ (Overview)

CAMS เป็นระบบบริหารจัดการทะเบียนและวงจรชีวิตของอุปกรณ์สื่อสาร (วิทยุ, เครื่องมือสื่อสารภาคพื้น, อุปกรณ์เสริม ฯลฯ) เพื่อการตรวจสอบและรับผิดชอบ (accountability & audit) ตั้งแต่รับเข้าคลังจนถึงจำหน่ายออก โดยติดตามสถานะและผู้ครอบครองอุปกรณ์แต่ละชิ้นแบบ real-time พร้อมประวัติการเคลื่อนไหวแบบครบวงจร (full audit trail)

### วงจรชีวิตอุปกรณ์ (Lifecycle)

```
รับเข้า (RECEIVE)
   │
   ▼
คลัง (IN_STOCK) ──────────────┐
   │                          │
   ▼                          ▼
เบิกจ่าย (ISSUE)          ส่งซ่อม (REPAIR)
   │                          │
   ▼                          ▼
ครอบครอง (ASSIGNED) ◄──── กลับจากซ่อม
   │      ▲
   │      │
   ├─► โอน (TRANSFER) ──────┘ (เปลี่ยนผู้ครอบครอง)
   │
   ├─► ยืม-คืน (BORROW/RETURN) ── ชั่วคราว กลับสู่ผู้ครอบครองเดิม
   │
   ├─► ตรวจสอบ (INSPECTION) ── ตามรอบ ไม่เปลี่ยนสถานะถ้าผ่าน
   │
   └─► จำหน่าย (DISPOSAL) ──► จำหน่ายถาวร (DISPOSED)
```

---

## 2. สถาปัตยกรรมระบบ (3-Tier Architecture)

```
┌─────────────────────────────────────────────────────────┐
│  Presentation Tier                                        │
│  Bootstrap 5 + Vanilla JS (server-rendered views + AJAX)   │
│  - Login / Dashboard / ทะเบียนอุปกรณ์ / ธุรกรรมต่างๆ         │
└───────────────────────┬─────────────────────────────────┘
                         │ HTTPS (intranet only)
┌───────────────────────▼─────────────────────────────────┐
│  Application Tier                                          │
│  PHP 8 + CodeIgniter 4 (MVC)                               │
│  - Controllers (per module) / Models / Services             │
│  - RBAC middleware (role/permission check ทุก request)      │
│  - Validation, transaction/document number generation       │
└───────────────────────┬─────────────────────────────────┘
                         │ MySQLi / Query Builder
┌───────────────────────▼─────────────────────────────────┐
│  Data Tier                                                  │
│  MySQL 8                                                    │
│  - ~20 tables (ดูหัวข้อ 4 ER Diagram)                        │
│  - ไฟล์แนบเก็บบน local filesystem, path อ้างอิงในตาราง        │
└─────────────────────────────────────────────────────────┘
```

**Deployment:** ติดตั้งแบบ standalone บนเครื่อง/เซิร์ฟเวอร์ภายในหน่วย ไม่มีการเชื่อมต่ออินเทอร์เน็ตหรือบริการภายนอกใดๆ (ตรงข้ามกับ TTX Exercise Clock ซึ่ง deploy ผ่าน GitHub Pages — CAMS ไม่ได้อยู่บน public internet)

---

## 3. บทบาทและสิทธิ์ (Roles & Permissions)

| บทบาท | คำอธิบาย | ขอบเขต |
|---|---|---|
| `SUPER_ADMIN` | ผู้ดูแลระบบสูงสุด | ทุกหน่วย, ทุกโมดูล, ตั้งค่าระบบ, จัดการผู้ใช้/สิทธิ์ |
| `UNIT_ADMIN` | ผู้ดูแลระบบระดับหน่วย | เฉพาะหน่วยตนเอง, ทุกโมดูลในหน่วย |
| `OFFICER` | เจ้าหน้าที่ปฏิบัติงาน | สร้าง/แก้ไขธุรกรรมในหน่วยตนเอง (รับเข้า/เบิกจ่าย/โอน/ยืม-คืน/ซ่อม) รอการอนุมัติ |
| `APPROVER` | ผู้อนุมัติ | อนุมัติ/ปฏิเสธธุรกรรมที่ต้องการการอนุมัติในหน่วยตนเอง |
| `VIEWER` | ผู้ดูอย่างเดียว | ดูรายงาน/ทะเบียน อ่านอย่างเดียว ไม่มีสิทธิ์แก้ไข |

### Permission Matrix (สรุปย่อ — รายละเอียดเต็มอยู่ใน `role_permissions` table)

| โมดูล | SUPER_ADMIN | UNIT_ADMIN | OFFICER | APPROVER | VIEWER |
|---|:---:|:---:|:---:|:---:|:---:|
| ทะเบียนอุปกรณ์ | CRUD | CRUD (หน่วยตน) | R | R | R |
| รับเข้า/เบิกจ่าย/โอน/ยืม-คืน/ซ่อม | CRUD | CRUD (หน่วยตน) | C, R, U (ของตน) | R + Approve | R |
| ตรวจสอบ | CRUD | CRUD (หน่วยตน) | C, R | R + Approve | R |
| จำหน่าย | CRUD | CRUD (หน่วยตน) | C (เสนอ) | R + Approve | R |
| รายงาน | R | R (หน่วยตน) | R (หน่วยตน) | R (หน่วยตน) | R (หน่วยตน) |
| ผู้ดูแลระบบ (users/roles/settings) | CRUD | R/U (หน่วยตน) | - | - | - |

---

## 4. สถานะอุปกรณ์ — State Machine (`asset_statuses`)

| รหัสสถานะ | ความหมาย | สีป้าย (tag) |
|---|---|---|
| `IN_STOCK` | อยู่ในคลัง พร้อมเบิกจ่าย | เขียว (steel) |
| `ASSIGNED` | มีผู้ครอบครองอยู่ | เขียว (green) |
| `BORROWED` | อยู่ระหว่างถูกยืม | เหลืองอำพัน (amber) |
| `REPAIR` | อยู่ระหว่างส่งซ่อม | เหลืองอำพัน (amber) |
| `DAMAGED` | ชำรุด รอพิจารณา | แดง (red) |
| `LOST` | สูญหาย | แดง (red) |
| `INSPECTION` | อยู่ระหว่างการตรวจสอบ | ฟ้าเหล็ก (steel) |
| `DISPOSAL` | เสนอจำหน่าย (undo ได้) | แดง (red) |
| `DISPOSED` | จำหน่ายถาวรแล้ว | เทา (neutral) |

**กฎสำคัญ:** ห้ามลบ record ของ asset เด็ดขาด (no hard delete) — การ "เอาออกจากระบบ" ทำได้เฉพาะผ่านสถานะ `DISPOSED` เท่านั้น ทุกการเปลี่ยนสถานะบันทึกใน `audit_logs` และ/หรือ transaction ที่เกี่ยวข้องเสมอ เพื่อรักษาความสามารถในการตรวจสอบย้อนหลัง (auditability)

---

## 5. โมดูลและ Workflow

แต่ละธุรกรรมมีเลขที่เอกสาร (document number) รูปแบบ `{PREFIX}-{ปีพ.ศ.}-{running}` เช่น `REC-2569-00042`

| โมดูล | Prefix | คำอธิบาย workflow |
|---|---|---|
| รับเข้า (Receive) | `REC-` | บันทึกอุปกรณ์ใหม่เข้าคลัง → สร้าง `assets` record + `documents` → สถานะเริ่มต้น `IN_STOCK` |
| เบิกจ่าย (Issue) | `ISS-` | จ่ายจากคลังให้บุคคล/หน่วย → `IN_STOCK` → `ASSIGNED`, ผูก `personnel`/`unit` เป็นผู้ครอบครอง |
| ครอบครอง (Custody) | — | ไม่ใช่ธุรกรรมแยก แต่เป็น "สถานะปัจจุบัน" ของ asset ที่อ้างอิงจาก transaction ล่าสุด |
| โอน (Transfer) | `TRF-` | เปลี่ยนผู้ครอบครองจากคนหนึ่ง/หน่วยหนึ่ง ไปอีกคน/หน่วยหนึ่ง (`ASSIGNED` → `ASSIGNED`, เปลี่ยน holder) |
| ยืม-คืน (Borrow/Return) | `BRW-` | ยืมชั่วคราวจากผู้ครอบครองปัจจุบัน มีกำหนดคืน → `borrow_records` ติดตาม due date, แจ้งเตือนเมื่อเกินกำหนด → คืนแล้วกลับสู่ผู้ครอบครองเดิม |
| ซ่อม (Repair) | `REP-` | ส่งซ่อมเมื่อชำรุด → `ASSIGNED`/`IN_STOCK` → `REPAIR`, บันทึกอาการ/ผลซ่อม/ค่าใช้จ่ายใน `repair_records`, ซ่อมเสร็จกลับสถานะเดิม หรือ `DAMAGED` ถ้าซ่อมไม่ได้ |
| ตรวจสอบ (Inspection) | `INS-` | ตรวจนับตามรอบ (ประจำปี/ตามคำสั่ง) → `inspection_headers` + `inspection_items` รายชิ้น ผลตรวจ (พบ/ไม่พบ/ชำรุด) ไม่พบ → เปลี่ยนสถานะเป็น `LOST` |
| จำหน่าย (Disposal) | `DSP-` | เสนอจำหน่ายจากสถานะใดก็ได้ (เก็บสถานะเดิมไว้ undo) → รออนุมัติ → ยืนยันจำหน่ายถาวร (`DISPOSED`, ย้อนกลับไม่ได้) หรือย้อนกลับ (`ย้อนกลับ` คืนสถานะเดิม) |

---

## 6. ER Diagram (ภาพรวมความสัมพันธ์)

```
roles ──< role_permissions >── permissions
  │
  └──< users >── personnel ──< units
                     │            │
                     │            └──< locations
                     │
assets ──> asset_models ──> asset_categories
  │
  ├──> asset_statuses (สถานะปัจจุบัน)
  ├──> personnel (ผู้ครอบครองปัจจุบัน, nullable)
  ├──> units (หน่วยครอบครองปัจจุบัน, nullable)
  ├──< attachments (ไฟล์แนบ, unlimited)
  │
  ├──< transaction_items >── transactions ── documents
  ├──< borrow_records
  ├──< repair_records
  ├──< inspection_items >── inspection_headers
  └──< audit_logs

system_settings (key-value, ตั้งค่าระบบทั่วไป)
```

รายละเอียดคอลัมน์ทั้งหมด: ดู `database-schema.sql` (21 ตาราง) ซึ่งต้องอัปเดตคู่กับเอกสารนี้เสมอเมื่อมีการเพิ่มตาราง/โมดูล/กฎธุรกิจใหม่

---

## 7. Screen Map

```
/login                          หน้าเข้าสู่ระบบ (+ role selector สำหรับ demo)
/dashboard                      ภาพรวม: KPI, ธุรกรรมล่าสุด, แจ้งเตือน
/assets                         ทะเบียนอุปกรณ์ (ค้นหา/กรอง/รายละเอียด)
/assets/:id                     รายละเอียดอุปกรณ์ (modal): spec, QR, ประวัติ, ไฟล์แนบ
/transactions/receive           รับเข้า
/transactions/issue             เบิกจ่าย
/transactions/transfer          โอน
/transactions/borrow            ยืม-คืน
/transactions/repair            ซ่อม
/inspections                    ตรวจสอบ
/disposal                       จำหน่าย (2-step: เสนอ → ยืนยัน/ย้อนกลับ)
/reports                        รายงาน
/admin/users                    ผู้ดูแลระบบ: ผู้ใช้
/admin/settings                 ผู้ดูแลระบบ: ตั้งค่า
```

---

## 8. REST API Design (โครงร่างเบื้องต้น — implement เมื่อเข้าสู่ backend phase)

```
POST   /api/auth/login
POST   /api/auth/logout

GET    /api/assets                 ?search=&status=&unit=&category=
GET    /api/assets/{id}
POST   /api/assets                 (ผ่าน receive transaction)
PATCH  /api/assets/{id}/status

GET    /api/transactions           ?type=&status=&unit=
POST   /api/transactions/receive
POST   /api/transactions/issue
POST   /api/transactions/transfer
POST   /api/transactions/borrow
POST   /api/transactions/borrow/{id}/return
POST   /api/transactions/repair
PATCH  /api/transactions/{id}/approve
PATCH  /api/transactions/{id}/reject

GET    /api/inspections
POST   /api/inspections
POST   /api/inspections/{id}/items

POST   /api/assets/{id}/disposal/submit
POST   /api/assets/{id}/disposal/confirm
POST   /api/assets/{id}/disposal/undo

GET    /api/assets/{id}/attachments
POST   /api/assets/{id}/attachments
DELETE /api/attachments/{id}

GET    /api/reports/summary
GET    /api/reports/audit-log
```

---

## 9. Non-Functional Requirements

- **ภาษา:** UI ภาษาไทยทั้งหมด (ยกเว้น code/S/N/เลขที่เอกสารซึ่งเป็นภาษาอังกฤษ/ตัวเลข)
- **ความปลอดภัย:** ไม่มีการเชื่อมต่อ internet/cloud/external API ใดๆ, RBAC บังคับทุก endpoint, audit log ทุกการเปลี่ยนแปลงข้อมูลสำคัญ
- **การลบข้อมูล:** ห้าม hard delete asset — ใช้ status flip เท่านั้น (soft lifecycle)
- **Availability:** ระบบภายในหน่วย ไม่ต้องรองรับ high-availability/scale ระดับ cloud
- **Auditability:** ทุก transaction ต้องย้อนดูได้ว่าใครทำอะไร เมื่อไร กับ asset ชิ้นไหน

---

## Changelog

- **v0.1** (initial) — สร้างเอกสารเริ่มต้นพร้อม prototype แรก: architecture, ER diagram (21 ตาราง), state machine, permission matrix, screen map, REST API design
