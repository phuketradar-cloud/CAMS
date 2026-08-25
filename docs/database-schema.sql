-- =====================================================================
-- CAMS — Communication Asset Management System
-- Database Schema (MySQL 8)
-- Target stack: PHP 8 + CodeIgniter 4
-- Status: v0.1 — matches CAMS-System-Design.md ER diagram (21 tables)
-- NOTE: status codes / document prefixes / approval hierarchy are
-- provisional pending RTAF regulation review — kept data-driven
-- (asset_statuses.name_th, system_settings) rather than hardcoded.
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- 1. roles
-- ---------------------------------------------------------------------
CREATE TABLE roles (
    role_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code          VARCHAR(30)  NOT NULL UNIQUE,   -- SUPER_ADMIN, UNIT_ADMIN, OFFICER, APPROVER, VIEWER
    name_th       VARCHAR(100) NOT NULL,
    description   VARCHAR(255) NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 2. permissions
-- ---------------------------------------------------------------------
CREATE TABLE permissions (
    permission_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code          VARCHAR(60)  NOT NULL UNIQUE,   -- e.g. asset.create, transaction.approve
    module        VARCHAR(40)  NOT NULL,          -- assets, transactions, inspections, disposal, reports, admin
    name_th       VARCHAR(120) NOT NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 3. role_permissions (junction)
-- ---------------------------------------------------------------------
CREATE TABLE role_permissions (
    role_id       INT UNSIGNED NOT NULL,
    permission_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES roles(role_id),
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES permissions(permission_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 4. units (หน่วยงาน)
-- ---------------------------------------------------------------------
CREATE TABLE units (
    unit_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code          VARCHAR(30)  NOT NULL UNIQUE,
    name_th       VARCHAR(150) NOT NULL,
    parent_unit_id INT UNSIGNED NULL,
    is_active     TINYINT(1) NOT NULL DEFAULT 1,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_units_parent FOREIGN KEY (parent_unit_id) REFERENCES units(unit_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 5. locations (สถานที่จัดเก็บ/ประจำการ)
-- ---------------------------------------------------------------------
CREATE TABLE locations (
    location_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    unit_id       INT UNSIGNED NOT NULL,
    code          VARCHAR(30)  NOT NULL,
    name_th       VARCHAR(150) NOT NULL,
    is_active     TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT fk_locations_unit FOREIGN KEY (unit_id) REFERENCES units(unit_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 6. personnel (กำลังพล)
-- ---------------------------------------------------------------------
CREATE TABLE personnel (
    personnel_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    service_id    VARCHAR(30)  NOT NULL UNIQUE,   -- เลขประจำตัว
    rank_th       VARCHAR(30)  NULL,
    full_name_th  VARCHAR(150) NOT NULL,
    unit_id       INT UNSIGNED NOT NULL,
    position_th   VARCHAR(150) NULL,
    phone         VARCHAR(20)  NULL,
    is_active     TINYINT(1) NOT NULL DEFAULT 1,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_personnel_unit FOREIGN KEY (unit_id) REFERENCES units(unit_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 7. users (บัญชีผู้ใช้งานระบบ)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    personnel_id  INT UNSIGNED NULL,
    username      VARCHAR(60)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role_id       INT UNSIGNED NOT NULL,
    unit_id       INT UNSIGNED NOT NULL,           -- ขอบเขตข้อมูลที่มองเห็น
    is_active     TINYINT(1) NOT NULL DEFAULT 1,
    last_login_at DATETIME NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_users_personnel FOREIGN KEY (personnel_id) REFERENCES personnel(personnel_id),
    CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(role_id),
    CONSTRAINT fk_users_unit FOREIGN KEY (unit_id) REFERENCES units(unit_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 8. asset_categories (หมวดหมู่อุปกรณ์)
-- ---------------------------------------------------------------------
CREATE TABLE asset_categories (
    category_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code          VARCHAR(30)  NOT NULL UNIQUE,
    name_th       VARCHAR(120) NOT NULL,
    parent_category_id INT UNSIGNED NULL,
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_category_id) REFERENCES asset_categories(category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 9. asset_models (รุ่น/แบบอุปกรณ์)
-- ---------------------------------------------------------------------
CREATE TABLE asset_models (
    model_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_id   INT UNSIGNED NOT NULL,
    brand         VARCHAR(100) NULL,
    model_name    VARCHAR(150) NOT NULL,
    spec_json     JSON NULL,                       -- สเปกเพิ่มเติมตามชนิดอุปกรณ์
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_model_category FOREIGN KEY (category_id) REFERENCES asset_categories(category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 10. asset_statuses (สถานะ — data-driven ตามข้อ 4 ของ design doc)
-- ---------------------------------------------------------------------
CREATE TABLE asset_statuses (
    status_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code          VARCHAR(30)  NOT NULL UNIQUE,   -- IN_STOCK, ASSIGNED, BORROWED, REPAIR, DAMAGED, LOST, INSPECTION, DISPOSAL, DISPOSED
    name_th       VARCHAR(100) NOT NULL,          -- editable — ยังไม่ใช่ terminology สุดท้าย
    color_tag     VARCHAR(20)  NOT NULL DEFAULT 'steel',
    is_terminal   TINYINT(1) NOT NULL DEFAULT 0,  -- 1 เฉพาะ DISPOSED
    sort_order    SMALLINT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 11. assets (ทะเบียนอุปกรณ์ — ตารางหลัก)
-- ---------------------------------------------------------------------
CREATE TABLE assets (
    asset_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    asset_code       VARCHAR(40)  NOT NULL UNIQUE,   -- รหัสครุภัณฑ์
    serial_number    VARCHAR(100) NULL,
    model_id         INT UNSIGNED NOT NULL,
    status_id        INT UNSIGNED NOT NULL,
    prev_status_id   INT UNSIGNED NULL,              -- เก็บสถานะก่อนเสนอจำหน่าย เพื่อรองรับ "ย้อนกลับ"
    current_unit_id  INT UNSIGNED NULL,               -- หน่วยที่ครอบครองปัจจุบัน
    current_holder_id INT UNSIGNED NULL,              -- personnel ที่ครอบครองปัจจุบัน (nullable = อยู่คลัง)
    current_location_id INT UNSIGNED NULL,
    acquired_date    DATE NULL,
    acquired_cost    DECIMAL(12,2) NULL,
    warranty_until   DATE NULL,
    remarks          TEXT NULL,
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_assets_model FOREIGN KEY (model_id) REFERENCES asset_models(model_id),
    CONSTRAINT fk_assets_status FOREIGN KEY (status_id) REFERENCES asset_statuses(status_id),
    CONSTRAINT fk_assets_prev_status FOREIGN KEY (prev_status_id) REFERENCES asset_statuses(status_id),
    CONSTRAINT fk_assets_unit FOREIGN KEY (current_unit_id) REFERENCES units(unit_id),
    CONSTRAINT fk_assets_holder FOREIGN KEY (current_holder_id) REFERENCES personnel(personnel_id),
    CONSTRAINT fk_assets_location FOREIGN KEY (current_location_id) REFERENCES locations(location_id),
    INDEX idx_assets_status (status_id),
    INDEX idx_assets_unit (current_unit_id),
    INDEX idx_assets_search (asset_code, serial_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 12. attachments (ไฟล์แนบต่อ asset — ไม่จำกัดจำนวน)
-- ---------------------------------------------------------------------
CREATE TABLE attachments (
    attachment_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    asset_id       INT UNSIGNED NOT NULL,
    file_name      VARCHAR(255) NOT NULL,
    file_path      VARCHAR(500) NOT NULL,           -- local filesystem path
    mime_type      VARCHAR(120) NULL,
    file_size      INT UNSIGNED NULL,               -- bytes
    uploaded_by    INT UNSIGNED NOT NULL,
    uploaded_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_attachments_asset FOREIGN KEY (asset_id) REFERENCES assets(asset_id),
    CONSTRAINT fk_attachments_user FOREIGN KEY (uploaded_by) REFERENCES users(user_id),
    INDEX idx_attachments_asset (asset_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 13. documents (เอกสารอ้างอิงของธุรกรรม — เลขที่เอกสาร)
-- ---------------------------------------------------------------------
CREATE TABLE documents (
    document_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    document_no    VARCHAR(40)  NOT NULL UNIQUE,    -- e.g. REC-2569-00042
    document_type  VARCHAR(20)  NOT NULL,           -- REC, ISS, TRF, BRW, REP, INS, DSP
    issued_date    DATE NOT NULL,
    file_path      VARCHAR(500) NULL,               -- สแกนเอกสารต้นฉบับ (ถ้ามี)
    created_by     INT UNSIGNED NOT NULL,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_documents_user FOREIGN KEY (created_by) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 14. transactions (หัวธุรกรรม — รับเข้า/เบิกจ่าย/โอน)
-- ---------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    document_id     INT UNSIGNED NOT NULL,
    transaction_type VARCHAR(20) NOT NULL,           -- RECEIVE, ISSUE, TRANSFER
    from_unit_id     INT UNSIGNED NULL,
    from_holder_id   INT UNSIGNED NULL,
    to_unit_id       INT UNSIGNED NULL,
    to_holder_id     INT UNSIGNED NULL,
    status           VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- PENDING, APPROVED, REJECTED
    requested_by     INT UNSIGNED NOT NULL,
    approved_by      INT UNSIGNED NULL,
    approved_at      DATETIME NULL,
    remarks          TEXT NULL,
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_tx_document FOREIGN KEY (document_id) REFERENCES documents(document_id),
    CONSTRAINT fk_tx_from_unit FOREIGN KEY (from_unit_id) REFERENCES units(unit_id),
    CONSTRAINT fk_tx_from_holder FOREIGN KEY (from_holder_id) REFERENCES personnel(personnel_id),
    CONSTRAINT fk_tx_to_unit FOREIGN KEY (to_unit_id) REFERENCES units(unit_id),
    CONSTRAINT fk_tx_to_holder FOREIGN KEY (to_holder_id) REFERENCES personnel(personnel_id),
    CONSTRAINT fk_tx_requested_by FOREIGN KEY (requested_by) REFERENCES users(user_id),
    CONSTRAINT fk_tx_approved_by FOREIGN KEY (approved_by) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 15. transaction_items (รายการอุปกรณ์ในแต่ละธุรกรรม — 1 ธุรกรรมมีได้หลายชิ้น)
-- ---------------------------------------------------------------------
CREATE TABLE transaction_items (
    transaction_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    transaction_id  INT UNSIGNED NOT NULL,
    asset_id        INT UNSIGNED NOT NULL,
    status_before_id INT UNSIGNED NULL,
    status_after_id  INT UNSIGNED NULL,
    remarks          VARCHAR(255) NULL,
    CONSTRAINT fk_ti_transaction FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    CONSTRAINT fk_ti_asset FOREIGN KEY (asset_id) REFERENCES assets(asset_id),
    CONSTRAINT fk_ti_status_before FOREIGN KEY (status_before_id) REFERENCES asset_statuses(status_id),
    CONSTRAINT fk_ti_status_after FOREIGN KEY (status_after_id) REFERENCES asset_statuses(status_id),
    INDEX idx_ti_transaction (transaction_id),
    INDEX idx_ti_asset (asset_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 16. borrow_records (ยืม-คืน)
-- ---------------------------------------------------------------------
CREATE TABLE borrow_records (
    borrow_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    document_id       INT UNSIGNED NOT NULL,
    asset_id          INT UNSIGNED NOT NULL,
    borrower_id        INT UNSIGNED NOT NULL,        -- personnel ผู้ยืม
    lender_holder_id   INT UNSIGNED NULL,             -- ผู้ครอบครองเดิมก่อนยืม (สำหรับคืนกลับ)
    borrow_date        DATE NOT NULL,
    due_date            DATE NOT NULL,
    return_date         DATE NULL,
    is_returned         TINYINT(1) NOT NULL DEFAULT 0,
    approved_by         INT UNSIGNED NULL,
    remarks             VARCHAR(255) NULL,
    created_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_borrow_document FOREIGN KEY (document_id) REFERENCES documents(document_id),
    CONSTRAINT fk_borrow_asset FOREIGN KEY (asset_id) REFERENCES assets(asset_id),
    CONSTRAINT fk_borrow_borrower FOREIGN KEY (borrower_id) REFERENCES personnel(personnel_id),
    CONSTRAINT fk_borrow_lender FOREIGN KEY (lender_holder_id) REFERENCES personnel(personnel_id),
    CONSTRAINT fk_borrow_approved_by FOREIGN KEY (approved_by) REFERENCES users(user_id),
    INDEX idx_borrow_due (due_date, is_returned)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 17. repair_records (ซ่อม)
-- ---------------------------------------------------------------------
CREATE TABLE repair_records (
    repair_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    document_id       INT UNSIGNED NOT NULL,
    asset_id          INT UNSIGNED NOT NULL,
    symptom            TEXT NOT NULL,                 -- อาการชำรุด
    sent_date           DATE NOT NULL,
    vendor_or_unit       VARCHAR(150) NULL,             -- ผู้รับซ่อม (ร้าน/หน่วยซ่อมภายใน)
    expected_return_date DATE NULL,
    actual_return_date   DATE NULL,
    result               VARCHAR(20) NULL,              -- REPAIRED, UNREPAIRABLE, PENDING
    cost                 DECIMAL(12,2) NULL,
    remarks              TEXT NULL,
    approved_by           INT UNSIGNED NULL,
    created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_repair_document FOREIGN KEY (document_id) REFERENCES documents(document_id),
    CONSTRAINT fk_repair_asset FOREIGN KEY (asset_id) REFERENCES assets(asset_id),
    CONSTRAINT fk_repair_approved_by FOREIGN KEY (approved_by) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 18. inspection_headers (รอบการตรวจสอบ)
-- ---------------------------------------------------------------------
CREATE TABLE inspection_headers (
    inspection_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    document_id        INT UNSIGNED NOT NULL,
    unit_id             INT UNSIGNED NOT NULL,
    inspection_date       DATE NOT NULL,
    inspector_id           INT UNSIGNED NOT NULL,       -- personnel ผู้ตรวจ
    status                  VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS', -- IN_PROGRESS, COMPLETED
    remarks                 TEXT NULL,
    created_at               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_insphead_document FOREIGN KEY (document_id) REFERENCES documents(document_id),
    CONSTRAINT fk_insphead_unit FOREIGN KEY (unit_id) REFERENCES units(unit_id),
    CONSTRAINT fk_insphead_inspector FOREIGN KEY (inspector_id) REFERENCES personnel(personnel_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 19. inspection_items (ผลตรวจรายชิ้น)
-- ---------------------------------------------------------------------
CREATE TABLE inspection_items (
    inspection_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    inspection_id       INT UNSIGNED NOT NULL,
    asset_id             INT UNSIGNED NOT NULL,
    result_code           VARCHAR(20) NOT NULL,          -- FOUND_OK, FOUND_DAMAGED, NOT_FOUND
    remarks                VARCHAR(255) NULL,
    CONSTRAINT fk_inspitem_header FOREIGN KEY (inspection_id) REFERENCES inspection_headers(inspection_id),
    CONSTRAINT fk_inspitem_asset FOREIGN KEY (asset_id) REFERENCES assets(asset_id),
    INDEX idx_inspitem_inspection (inspection_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 20. audit_logs (ประวัติการเปลี่ยนแปลงทั้งหมด)
-- ---------------------------------------------------------------------
CREATE TABLE audit_logs (
    audit_id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    asset_id         INT UNSIGNED NULL,
    user_id           INT UNSIGNED NULL,
    action_code        VARCHAR(40) NOT NULL,             -- e.g. STATUS_CHANGE, TRANSFER, DISPOSAL_SUBMIT, DISPOSAL_CONFIRM, DISPOSAL_UNDO
    entity_type          VARCHAR(40) NOT NULL,           -- assets, transactions, borrow_records, ...
    entity_id             INT UNSIGNED NULL,
    detail_json            JSON NULL,                    -- before/after snapshot
    created_at              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_asset FOREIGN KEY (asset_id) REFERENCES assets(asset_id),
    CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    INDEX idx_audit_asset (asset_id),
    INDEX idx_audit_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 21. system_settings (key-value ตั้งค่าระบบ)
-- ---------------------------------------------------------------------
CREATE TABLE system_settings (
    setting_key    VARCHAR(80) PRIMARY KEY,
    setting_value  TEXT NULL,
    description    VARCHAR(255) NULL,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- Seed data — reference tables only
-- =====================================================================

INSERT INTO roles (code, name_th, description) VALUES
    ('SUPER_ADMIN', 'ผู้ดูแลระบบสูงสุด', 'สิทธิ์เต็มทุกหน่วยทุกโมดูล'),
    ('UNIT_ADMIN',  'ผู้ดูแลระบบหน่วย',   'สิทธิ์เต็มเฉพาะหน่วยตนเอง'),
    ('OFFICER',     'เจ้าหน้าที่ปฏิบัติงาน', 'สร้าง/แก้ไขธุรกรรมในหน่วยตนเอง'),
    ('APPROVER',    'ผู้อนุมัติ',          'อนุมัติ/ปฏิเสธธุรกรรมในหน่วยตนเอง'),
    ('VIEWER',      'ผู้ดูอย่างเดียว',      'อ่านอย่างเดียว');

INSERT INTO asset_statuses (code, name_th, color_tag, is_terminal, sort_order) VALUES
    ('IN_STOCK',   'อยู่ในคลัง',         'steel', 0, 1),
    ('ASSIGNED',   'ครอบครองอยู่',       'green', 0, 2),
    ('BORROWED',   'ถูกยืม',            'amber', 0, 3),
    ('REPAIR',     'ส่งซ่อม',           'amber', 0, 4),
    ('DAMAGED',    'ชำรุด',             'red',   0, 5),
    ('LOST',       'สูญหาย',            'red',   0, 6),
    ('INSPECTION', 'อยู่ระหว่างตรวจสอบ', 'steel', 0, 7),
    ('DISPOSAL',   'เสนอจำหน่าย',        'red',   0, 8),
    ('DISPOSED',   'จำหน่ายแล้ว',        'neutral', 1, 9);

INSERT INTO system_settings (setting_key, setting_value, description) VALUES
    ('document_prefix_receive',  'REC', 'เลขที่เอกสารรับเข้า'),
    ('document_prefix_issue',    'ISS', 'เลขที่เอกสารเบิกจ่าย'),
    ('document_prefix_transfer', 'TRF', 'เลขที่เอกสารโอน'),
    ('document_prefix_borrow',   'BRW', 'เลขที่เอกสารยืม-คืน'),
    ('document_prefix_repair',   'REP', 'เลขที่เอกสารซ่อม'),
    ('document_prefix_inspect',  'INS', 'เลขที่เอกสารตรวจสอบ'),
    ('document_prefix_disposal', 'DSP', 'เลขที่เอกสารจำหน่าย');
