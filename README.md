# CAMS — Communication Asset Management System

UI-first interactive prototype ของระบบบริหารจัดการทะเบียนและวงจรชีวิตอุปกรณ์สื่อสาร สำหรับ RTAF RCC (Rescue Coordination Centre)

**สถานะ:** Prototype — ยังไม่มี backend จริง ข้อมูลทั้งหมดเป็น mock data ที่รันอยู่ในเบราว์เซอร์ล้วนๆ (ไม่มีการเชื่อมต่อฐานข้อมูลหรือ API ภายนอกใดๆ)

## เปิดดู

- **GitHub Pages** (หลังเปิดใช้งานตามขั้นตอนด้านล่าง): `https://phuketradar-cloud.github.io/CAMS/`
- หรือดาวน์โหลด `index.html` มาเปิดในเบราว์เซอร์โดยตรง — ไฟล์เดียวจบ ไม่ต้อง build ไม่ต้องมี internet (ยกเว้นฟอนต์ Google Fonts และการสแกนกล้อง)

## ไฟล์ในโปรเจกต์

| ไฟล์ | คำอธิบาย |
|---|---|
| `index.html` | ต้นแบบ UI แบบโต้ตอบได้ (single-file, inline CSS/JS, ไม่มี build step) |
| `docs/CAMS-System-Design.md` | เอกสารออกแบบระบบ — สถาปัตยกรรม 3-tier, ER diagram, state machine, permission matrix, screen map, REST API design |
| `docs/database-schema.sql` | MySQL 8 schema (21 ตาราง) ตรงกับเอกสารออกแบบ พร้อม seed data อ้างอิง |

## ฟีเจอร์ในต้นแบบ

- **Login** จำลองบทบาท 5 ระดับ: SUPER_ADMIN / UNIT_ADMIN / OFFICER / APPROVER / VIEWER
- **แดชบอร์ด** พร้อม KPI ที่คลิกดูรายละเอียดแยกตามสถานะ / ชนิดอุปกรณ์ / หน่วยได้ทันที
- **ทะเบียนอุปกรณ์** ค้นหาและกรองตามชนิด (วิทยุสื่อสาร / คอมพิวเตอร์ / ปริ้นเตอร์ / อื่นๆ), สถานะ, หน่วย
- **รับเข้าอุปกรณ์ใหม่** พร้อมสร้าง QR โค้ดเฉพาะอุปกรณ์ชิ้นนั้น (สแกนได้จริง ไม่ใช่ QR จำลอง) และพิมพ์ป้ายได้
- **สแกน QR** ผ่านกล้องมือถือ/แท็บเล็ต เปิดรายละเอียดอุปกรณ์ได้ทันที พร้อมช่องกรอกรหัสด้วยตนเองสำรอง
- **โอนอุปกรณ์** และ **จำหน่ายอุปกรณ์** (workflow 2 ขั้นตอน เสนอจำหน่าย → ยืนยัน/ย้อนกลับ)
- โมดูลที่เหลือ (เบิกจ่าย, ยืม-คืน, ซ่อม, ตรวจสอบ, รายงาน, ผู้ดูแลระบบ) แสดงเป็นสรุป workflow ไว้ก่อน รอพัฒนาเป็น UI เต็มรูปแบบ

## Stack เป้าหมายเมื่อขึ้น production (ยังไม่ implement ในต้นแบบนี้)

PHP 8 + CodeIgniter 4 · MySQL 8 · Bootstrap 5 + Vanilla JS · ติดตั้งแบบ standalone ภายในหน่วย ไม่เชื่อมต่อ cloud หรือ API ภายนอก

## เปิดใช้งาน GitHub Pages

1. ไปที่ **Settings → Pages**
2. Source: **Deploy from a branch**
3. Branch: **main** / Folder: **/(root)**
4. กด **Save** — รอสักครู่แล้วเว็บจะขึ้นที่ `https://phuketradar-cloud.github.io/CAMS/`

อัปเดตครั้งถัดไป: แก้ `index.html` แล้ว commit ขึ้น `main` เว็บจะ redeploy ให้อัตโนมัติ

---

*ชื่อสถานะ, terminology เอกสารราชการ, ลำดับชั้นการอนุมัติในต้นแบบนี้ยังไม่ใช่ข้อสรุปสุดท้าย — รอการตรวจทานจากระเบียบ ทอ. ที่เกี่ยวข้อง*
