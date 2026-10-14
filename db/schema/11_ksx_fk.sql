-- =============================================================================
-- 표준 존 FK — 관계목록 575행 중 물리 FK 로 옮길 수 있는 것
-- 생성: tools/gen_schema.py
-- 모두 DEFERRABLE INITIALLY DEFERRED: 레이크 적재는 원천별로 순서가 뒤섞여 들어오므로
-- 한 적재 트랜잭션 안에서는 순서를 따지지 않고, 커밋 시점에만 정합성을 본다.
-- 비용 (리뷰 F11, 30만 행·FK 7개 실측): 지연 검사는 커밋에 몰려 적재 시간의 ~64%. 지연 큐는 커밋까지 메모리에 남는다.
--   · 적재 트랜잭션은 50만 행 이하로 자른다.
--   · 부모가 먼저 들어오는 원천(기준정보 → 트랜잭션)은 SET CONSTRAINTS ALL IMMEDIATE.
--   · 초기 적재·백필은 gov.fk_bulk_begin('ksx.x') → COPY → gov.fk_bulk_end('ksx.x') (FK 를 NOT VALID 로 다시 걸고 나눠 VALIDATE).
-- 기존 데이터에 걸 때는 NOT VALID 로 먼저 걸고 VALIDATE CONSTRAINT 로 나눠 검증한다.
-- 제외: 다형 참조 4 · 표준 외 대상 3 · 하위 목록 참조 1 (→ SHACL/애플리케이션 검증)
-- =============================================================================

ALTER TABLE ksx.site ADD CONSTRAINT fk_site_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.plant ADD CONSTRAINT fk_plant_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.plant ADD CONSTRAINT fk_plant_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.department ADD CONSTRAINT fk_department_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.department ADD CONSTRAINT fk_department_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.department ADD CONSTRAINT fk_department_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.department ADD CONSTRAINT fk_department_04 FOREIGN KEY (enterprise_id, parent_department_id)
    REFERENCES ksx.department (enterprise_id, department_id) DEFERRABLE INITIALLY DEFERRED; -- 자기 참조:
ALTER TABLE ksx.personnel ADD CONSTRAINT fk_personnel_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.personnel ADD CONSTRAINT fk_personnel_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.personnel ADD CONSTRAINT fk_personnel_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.personnel ADD CONSTRAINT fk_personnel_04 FOREIGN KEY (enterprise_id, department_id)
    REFERENCES ksx.department (enterprise_id, department_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.customer_party_master ADD CONSTRAINT fk_customer_party_master_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.customer_party_master ADD CONSTRAINT fk_customer_party_master_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.customer_party_master ADD CONSTRAINT fk_customer_party_master_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.vendor_party_master ADD CONSTRAINT fk_vendor_party_master_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.vendor_party_master ADD CONSTRAINT fk_vendor_party_master_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.vendor_party_master ADD CONSTRAINT fk_vendor_party_master_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.common_code_master ADD CONSTRAINT fk_common_code_master_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.common_code_master ADD CONSTRAINT fk_common_code_master_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.common_code_master ADD CONSTRAINT fk_common_code_master_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.common_code_master ADD CONSTRAINT fk_common_code_master_04 FOREIGN KEY (enterprise_id, parent_common_code_group, parent_common_code_id)
    REFERENCES ksx.common_code_master (enterprise_id, common_code_group, common_code_id) DEFERRABLE INITIALLY DEFERRED; -- 자기 참조: 상위 코드(복합 참조)
ALTER TABLE ksx.work_calendar ADD CONSTRAINT fk_work_calendar_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.work_calendar ADD CONSTRAINT fk_work_calendar_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.work_calendar ADD CONSTRAINT fk_work_calendar_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.uom_group ADD CONSTRAINT fk_uom_group_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.uom_group ADD CONSTRAINT fk_uom_group_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.uom_group ADD CONSTRAINT fk_uom_group_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.item_master ADD CONSTRAINT fk_item_master_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.item_master ADD CONSTRAINT fk_item_master_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.item_master ADD CONSTRAINT fk_item_master_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.item_master ADD CONSTRAINT fk_item_master_04 FOREIGN KEY (enterprise_id, main_customer_id)
    REFERENCES ksx.customer_party_master (enterprise_id, customer_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.item_master ADD CONSTRAINT fk_item_master_05 FOREIGN KEY (enterprise_id, main_vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.item_master ADD CONSTRAINT fk_item_master_06 FOREIGN KEY (enterprise_id, receipt_warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.item_master ADD CONSTRAINT fk_item_master_07 FOREIGN KEY (enterprise_id, issue_warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.item_master ADD CONSTRAINT fk_item_master_08 FOREIGN KEY (enterprise_id, replacement_item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 자기 참조:
ALTER TABLE ksx.bom ADD CONSTRAINT fk_bom_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.bom ADD CONSTRAINT fk_bom_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.bom ADD CONSTRAINT fk_bom_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.bom ADD CONSTRAINT fk_bom_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.bom ADD CONSTRAINT fk_bom_05 FOREIGN KEY (enterprise_id, child_item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.bom ADD CONSTRAINT fk_bom_06 FOREIGN KEY (enterprise_id, routing_id, operation_sequence)
    REFERENCES ksx.routing (enterprise_id, routing_id, operation_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.bom_header ADD CONSTRAINT fk_bom_header_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.bom_header ADD CONSTRAINT fk_bom_header_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.bom_header ADD CONSTRAINT fk_bom_header_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.lot ADD CONSTRAINT fk_lot_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.lot ADD CONSTRAINT fk_lot_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.lot ADD CONSTRAINT fk_lot_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.lot ADD CONSTRAINT fk_lot_04 FOREIGN KEY (enterprise_id, parent_lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 자기 참조:
ALTER TABLE ksx.lot ADD CONSTRAINT fk_lot_05 FOREIGN KEY (enterprise_id, child_lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 자기 참조:
ALTER TABLE ksx.lot ADD CONSTRAINT fk_lot_06 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.lot ADD CONSTRAINT fk_lot_07 FOREIGN KEY (enterprise_id, carrier_id)
    REFERENCES ksx.carrier (enterprise_id, carrier_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.lot ADD CONSTRAINT fk_lot_08 FOREIGN KEY (enterprise_id, production_order_id, production_order_sequence)
    REFERENCES ksx.production_order (enterprise_id, production_order_id, production_order_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.lot ADD CONSTRAINT fk_lot_09 FOREIGN KEY (enterprise_id, current_operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.lot ADD CONSTRAINT fk_lot_10 FOREIGN KEY (enterprise_id, next_operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.lot ADD CONSTRAINT fk_lot_11 FOREIGN KEY (enterprise_id, personnel_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.routing ADD CONSTRAINT fk_routing_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.routing ADD CONSTRAINT fk_routing_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.routing ADD CONSTRAINT fk_routing_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.routing ADD CONSTRAINT fk_routing_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.routing ADD CONSTRAINT fk_routing_05 FOREIGN KEY (enterprise_id, operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.routing_header ADD CONSTRAINT fk_routing_header_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.routing_header ADD CONSTRAINT fk_routing_header_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.routing_header ADD CONSTRAINT fk_routing_header_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation ADD CONSTRAINT fk_operation_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation ADD CONSTRAINT fk_operation_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation ADD CONSTRAINT fk_operation_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.equipment ADD CONSTRAINT fk_equipment_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.equipment ADD CONSTRAINT fk_equipment_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.equipment ADD CONSTRAINT fk_equipment_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.equipment ADD CONSTRAINT fk_equipment_04 FOREIGN KEY (enterprise_id, parent_equipment_id)
    REFERENCES ksx.equipment (enterprise_id, equipment_id) DEFERRABLE INITIALLY DEFERRED; -- 자기 참조:
ALTER TABLE ksx.equipment ADD CONSTRAINT fk_equipment_05 FOREIGN KEY (enterprise_id, department_in_charge_id)
    REFERENCES ksx.department (enterprise_id, department_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.equipment ADD CONSTRAINT fk_equipment_06 FOREIGN KEY (enterprise_id, person_in_charge_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.equipment ADD CONSTRAINT fk_equipment_07 FOREIGN KEY (enterprise_id, operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.operation_equipment ADD CONSTRAINT fk_operation_equipment_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation_equipment ADD CONSTRAINT fk_operation_equipment_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation_equipment ADD CONSTRAINT fk_operation_equipment_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation_equipment ADD CONSTRAINT fk_operation_equipment_04 FOREIGN KEY (enterprise_id, operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.operation_equipment ADD CONSTRAINT fk_operation_equipment_05 FOREIGN KEY (enterprise_id, equipment_id)
    REFERENCES ksx.equipment (enterprise_id, equipment_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.carrier ADD CONSTRAINT fk_carrier_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.carrier ADD CONSTRAINT fk_carrier_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.carrier ADD CONSTRAINT fk_carrier_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.stocker_inventory ADD CONSTRAINT fk_stocker_inventory_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.stocker_inventory ADD CONSTRAINT fk_stocker_inventory_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.stocker_inventory ADD CONSTRAINT fk_stocker_inventory_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.stocker_inventory ADD CONSTRAINT fk_stocker_inventory_04 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.stocker_inventory ADD CONSTRAINT fk_stocker_inventory_05 FOREIGN KEY (enterprise_id, carrier_id)
    REFERENCES ksx.carrier (enterprise_id, carrier_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.stocker_inventory ADD CONSTRAINT fk_stocker_inventory_06 FOREIGN KEY (enterprise_id, alternate_stocker_id)
    REFERENCES ksx.stocker_inventory (enterprise_id, stocker_id) DEFERRABLE INITIALLY DEFERRED; -- 자기 참조:
ALTER TABLE ksx.warehouse_location ADD CONSTRAINT fk_warehouse_location_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.warehouse_location ADD CONSTRAINT fk_warehouse_location_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.warehouse_location ADD CONSTRAINT fk_warehouse_location_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.batch ADD CONSTRAINT fk_batch_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.batch ADD CONSTRAINT fk_batch_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.batch ADD CONSTRAINT fk_batch_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.batch ADD CONSTRAINT fk_batch_04 FOREIGN KEY (enterprise_id, parent_batch_id)
    REFERENCES ksx.batch (enterprise_id, batch_id) DEFERRABLE INITIALLY DEFERRED; -- 자기 참조:
ALTER TABLE ksx.batch ADD CONSTRAINT fk_batch_05 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.batch ADD CONSTRAINT fk_batch_06 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.batch ADD CONSTRAINT fk_batch_07 FOREIGN KEY (enterprise_id, production_order_id, production_order_sequence)
    REFERENCES ksx.production_order (enterprise_id, production_order_id, production_order_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.batch ADD CONSTRAINT fk_batch_08 FOREIGN KEY (enterprise_id, bom_id, bom_revision_number)
    REFERENCES ksx.bom_header (enterprise_id, bom_id, bom_revision_number) DEFERRABLE INITIALLY DEFERRED; -- 헤더 참조: 자재명세서 전체 참조 — 헤더 테이블 BOMHeader 경유 FK
ALTER TABLE ksx.batch ADD CONSTRAINT fk_batch_09 FOREIGN KEY (enterprise_id, operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.batch ADD CONSTRAINT fk_batch_10 FOREIGN KEY (enterprise_id, equipment_id)
    REFERENCES ksx.equipment (enterprise_id, equipment_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.batch ADD CONSTRAINT fk_batch_11 FOREIGN KEY (enterprise_id, personnel_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.line ADD CONSTRAINT fk_line_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.line ADD CONSTRAINT fk_line_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.line ADD CONSTRAINT fk_line_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.line ADD CONSTRAINT fk_line_04 FOREIGN KEY (enterprise_id, parent_line_id)
    REFERENCES ksx.line (enterprise_id, line_id) DEFERRABLE INITIALLY DEFERRED; -- 자기 참조:
ALTER TABLE ksx.line ADD CONSTRAINT fk_line_05 FOREIGN KEY (enterprise_id, department_in_charge_id)
    REFERENCES ksx.department (enterprise_id, department_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.line ADD CONSTRAINT fk_line_06 FOREIGN KEY (enterprise_id, person_in_charge_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.line ADD CONSTRAINT fk_line_07 FOREIGN KEY (enterprise_id, calendar_id)
    REFERENCES ksx.work_calendar (enterprise_id, calendar_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.line ADD CONSTRAINT fk_line_08 FOREIGN KEY (enterprise_id, issue_warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.line ADD CONSTRAINT fk_line_09 FOREIGN KEY (enterprise_id, receipt_warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.enterprise ADD CONSTRAINT fk_enterprise_01 FOREIGN KEY (parent_enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 자기 참조:
ALTER TABLE ksx.project_master ADD CONSTRAINT fk_project_master_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.project_master ADD CONSTRAINT fk_project_master_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.project_master ADD CONSTRAINT fk_project_master_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.project_master ADD CONSTRAINT fk_project_master_04 FOREIGN KEY (enterprise_id, responsible_department_id)
    REFERENCES ksx.department (enterprise_id, department_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.project_master ADD CONSTRAINT fk_project_master_05 FOREIGN KEY (enterprise_id, person_in_charge_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.project_master ADD CONSTRAINT fk_project_master_06 FOREIGN KEY (enterprise_id, sales_document_number, sales_document_sequence)
    REFERENCES ksx.sales_order (enterprise_id, sales_document_number, sales_document_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조: 대체키(문서번호+순번) 참조
ALTER TABLE ksx.project_master ADD CONSTRAINT fk_project_master_07 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.project_master ADD CONSTRAINT fk_project_master_08 FOREIGN KEY (enterprise_id, division_id)
    REFERENCES ksx.department (enterprise_id, department_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.engineering_change_order ADD CONSTRAINT fk_engineering_change_order_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.engineering_change_order ADD CONSTRAINT fk_engineering_change_order_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.engineering_change_order ADD CONSTRAINT fk_engineering_change_order_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.engineering_change_order ADD CONSTRAINT fk_engineering_change_order_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.engineering_change_order ADD CONSTRAINT fk_engineering_change_order_05 FOREIGN KEY (enterprise_id, bom_id, bom_revision_number, child_item_id)
    REFERENCES ksx.bom (enterprise_id, bom_id, bom_revision_number, child_item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.engineering_change_order ADD CONSTRAINT fk_engineering_change_order_06 FOREIGN KEY (enterprise_id, child_item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.sales_order ADD CONSTRAINT fk_sales_order_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.sales_order ADD CONSTRAINT fk_sales_order_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.sales_order ADD CONSTRAINT fk_sales_order_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.sales_order ADD CONSTRAINT fk_sales_order_04 FOREIGN KEY (enterprise_id, customer_id)
    REFERENCES ksx.customer_party_master (enterprise_id, customer_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.sales_order ADD CONSTRAINT fk_sales_order_05 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.sales_plan ADD CONSTRAINT fk_sales_plan_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.sales_plan ADD CONSTRAINT fk_sales_plan_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.sales_plan ADD CONSTRAINT fk_sales_plan_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.sales_plan ADD CONSTRAINT fk_sales_plan_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.base_price ADD CONSTRAINT fk_base_price_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.base_price ADD CONSTRAINT fk_base_price_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.base_price ADD CONSTRAINT fk_base_price_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.base_price ADD CONSTRAINT fk_base_price_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.purchase_requisition ADD CONSTRAINT fk_purchase_requisition_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.purchase_requisition ADD CONSTRAINT fk_purchase_requisition_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.purchase_requisition ADD CONSTRAINT fk_purchase_requisition_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.purchase_requisition ADD CONSTRAINT fk_purchase_requisition_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.purchase_requisition ADD CONSTRAINT fk_purchase_requisition_05 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.purchase_requisition ADD CONSTRAINT fk_purchase_requisition_06 FOREIGN KEY (enterprise_id, requester_department_id)
    REFERENCES ksx.department (enterprise_id, department_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.purchase_requisition ADD CONSTRAINT fk_purchase_requisition_07 FOREIGN KEY (enterprise_id, requester_personnel_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.purchase_order ADD CONSTRAINT fk_purchase_order_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.purchase_order ADD CONSTRAINT fk_purchase_order_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.purchase_order ADD CONSTRAINT fk_purchase_order_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.purchase_order ADD CONSTRAINT fk_purchase_order_04 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.purchase_order ADD CONSTRAINT fk_purchase_order_05 FOREIGN KEY (enterprise_id, personnel_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.purchase_order ADD CONSTRAINT fk_purchase_order_06 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.material_arrival ADD CONSTRAINT fk_material_arrival_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.material_arrival ADD CONSTRAINT fk_material_arrival_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.material_arrival ADD CONSTRAINT fk_material_arrival_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.material_arrival ADD CONSTRAINT fk_material_arrival_04 FOREIGN KEY (enterprise_id, purchase_document_number, purchase_document_sequence)
    REFERENCES ksx.purchase_order (enterprise_id, purchase_document_number, purchase_document_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조: 대체키(문서번호+순번) 참조
ALTER TABLE ksx.material_arrival ADD CONSTRAINT fk_material_arrival_05 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.material_arrival ADD CONSTRAINT fk_material_arrival_06 FOREIGN KEY (enterprise_id, receipt_warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.material_arrival ADD CONSTRAINT fk_material_arrival_07 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.material_arrival ADD CONSTRAINT fk_material_arrival_08 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.goods_receipt ADD CONSTRAINT fk_goods_receipt_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.goods_receipt ADD CONSTRAINT fk_goods_receipt_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.goods_receipt ADD CONSTRAINT fk_goods_receipt_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.goods_receipt ADD CONSTRAINT fk_goods_receipt_04 FOREIGN KEY (enterprise_id, warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.goods_receipt ADD CONSTRAINT fk_goods_receipt_05 FOREIGN KEY (enterprise_id, personnel_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.goods_receipt ADD CONSTRAINT fk_goods_receipt_06 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.goods_receipt ADD CONSTRAINT fk_goods_receipt_07 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.goods_issue ADD CONSTRAINT fk_goods_issue_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.goods_issue ADD CONSTRAINT fk_goods_issue_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.goods_issue ADD CONSTRAINT fk_goods_issue_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.goods_issue ADD CONSTRAINT fk_goods_issue_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.goods_issue ADD CONSTRAINT fk_goods_issue_05 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.goods_issue ADD CONSTRAINT fk_goods_issue_06 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.goods_issue ADD CONSTRAINT fk_goods_issue_07 FOREIGN KEY (enterprise_id, warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_planning ADD CONSTRAINT fk_production_planning_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_planning ADD CONSTRAINT fk_production_planning_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_planning ADD CONSTRAINT fk_production_planning_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_planning ADD CONSTRAINT fk_production_planning_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_order ADD CONSTRAINT fk_production_order_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_order ADD CONSTRAINT fk_production_order_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_order ADD CONSTRAINT fk_production_order_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_order ADD CONSTRAINT fk_production_order_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_order ADD CONSTRAINT fk_production_order_05 FOREIGN KEY (enterprise_id, line_id)
    REFERENCES ksx.line (enterprise_id, line_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_order ADD CONSTRAINT fk_production_order_06 FOREIGN KEY (enterprise_id, routing_id)
    REFERENCES ksx.routing_header (enterprise_id, routing_id) DEFERRABLE INITIALLY DEFERRED; -- 헤더 참조: 공정경로 전체 참조(표준 v1.0 표 45): 생산지시는 공정경로 전체를 따르며 공정순번은 지정하지 않음 — 헤더 테이블 RoutingHeader 경유 FK
ALTER TABLE ksx.production_order ADD CONSTRAINT fk_production_order_07 FOREIGN KEY (enterprise_id, bom_id, bom_revision_number)
    REFERENCES ksx.bom_header (enterprise_id, bom_id, bom_revision_number) DEFERRABLE INITIALLY DEFERRED; -- 헤더 참조: 자재명세서 전체 참조 — 헤더 테이블 BOMHeader 경유 FK
ALTER TABLE ksx.production_order ADD CONSTRAINT fk_production_order_08 FOREIGN KEY (enterprise_id, sales_document_number, sales_document_sequence)
    REFERENCES ksx.sales_order (enterprise_id, sales_document_number, sales_document_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조: 대체키(문서번호+순번) 참조
ALTER TABLE ksx.operation_start ADD CONSTRAINT fk_operation_start_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation_start ADD CONSTRAINT fk_operation_start_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation_start ADD CONSTRAINT fk_operation_start_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation_start ADD CONSTRAINT fk_operation_start_04 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.operation_start ADD CONSTRAINT fk_operation_start_05 FOREIGN KEY (enterprise_id, operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.operation_start ADD CONSTRAINT fk_operation_start_06 FOREIGN KEY (enterprise_id, equipment_id)
    REFERENCES ksx.equipment (enterprise_id, equipment_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.operation_start ADD CONSTRAINT fk_operation_start_07 FOREIGN KEY (enterprise_id, personnel_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.operation_end ADD CONSTRAINT fk_operation_end_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation_end ADD CONSTRAINT fk_operation_end_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation_end ADD CONSTRAINT fk_operation_end_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.operation_end ADD CONSTRAINT fk_operation_end_04 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.operation_end ADD CONSTRAINT fk_operation_end_05 FOREIGN KEY (enterprise_id, operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.operation_end ADD CONSTRAINT fk_operation_end_06 FOREIGN KEY (enterprise_id, equipment_id)
    REFERENCES ksx.equipment (enterprise_id, equipment_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.operation_end ADD CONSTRAINT fk_operation_end_07 FOREIGN KEY (enterprise_id, personnel_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.transfer_command ADD CONSTRAINT fk_transfer_command_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.transfer_command ADD CONSTRAINT fk_transfer_command_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.transfer_command ADD CONSTRAINT fk_transfer_command_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.transfer_command ADD CONSTRAINT fk_transfer_command_04 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.transfer_command ADD CONSTRAINT fk_transfer_command_05 FOREIGN KEY (enterprise_id, carrier_id)
    REFERENCES ksx.carrier (enterprise_id, carrier_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.transfer_start ADD CONSTRAINT fk_transfer_start_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.transfer_start ADD CONSTRAINT fk_transfer_start_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.transfer_start ADD CONSTRAINT fk_transfer_start_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.transfer_start ADD CONSTRAINT fk_transfer_start_04 FOREIGN KEY (enterprise_id, transfer_command_id)
    REFERENCES ksx.transfer_command (enterprise_id, transfer_command_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.transfer_start ADD CONSTRAINT fk_transfer_start_05 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.transfer_start ADD CONSTRAINT fk_transfer_start_06 FOREIGN KEY (enterprise_id, carrier_id)
    REFERENCES ksx.carrier (enterprise_id, carrier_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.transfer_end ADD CONSTRAINT fk_transfer_end_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.transfer_end ADD CONSTRAINT fk_transfer_end_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.transfer_end ADD CONSTRAINT fk_transfer_end_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.transfer_end ADD CONSTRAINT fk_transfer_end_04 FOREIGN KEY (enterprise_id, transfer_command_id)
    REFERENCES ksx.transfer_command (enterprise_id, transfer_command_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.transfer_end ADD CONSTRAINT fk_transfer_end_05 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.transfer_end ADD CONSTRAINT fk_transfer_end_06 FOREIGN KEY (enterprise_id, carrier_id)
    REFERENCES ksx.carrier (enterprise_id, carrier_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.in_transit_location ADD CONSTRAINT fk_in_transit_location_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.in_transit_location ADD CONSTRAINT fk_in_transit_location_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.in_transit_location ADD CONSTRAINT fk_in_transit_location_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.in_transit_location ADD CONSTRAINT fk_in_transit_location_04 FOREIGN KEY (enterprise_id, transfer_command_id)
    REFERENCES ksx.transfer_command (enterprise_id, transfer_command_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.in_transit_location ADD CONSTRAINT fk_in_transit_location_05 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.in_transit_location ADD CONSTRAINT fk_in_transit_location_06 FOREIGN KEY (enterprise_id, carrier_id)
    REFERENCES ksx.carrier (enterprise_id, carrier_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.equipment_state ADD CONSTRAINT fk_equipment_state_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.equipment_state ADD CONSTRAINT fk_equipment_state_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.equipment_state ADD CONSTRAINT fk_equipment_state_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.equipment_state ADD CONSTRAINT fk_equipment_state_04 FOREIGN KEY (enterprise_id, equipment_id)
    REFERENCES ksx.equipment (enterprise_id, equipment_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.equipment_state ADD CONSTRAINT fk_equipment_state_05 FOREIGN KEY (enterprise_id, last_processed_lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.equipment_state ADD CONSTRAINT fk_equipment_state_06 FOREIGN KEY (enterprise_id, last_processed_operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.alarm ADD CONSTRAINT fk_alarm_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.alarm ADD CONSTRAINT fk_alarm_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.alarm ADD CONSTRAINT fk_alarm_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.alarm ADD CONSTRAINT fk_alarm_04 FOREIGN KEY (enterprise_id, equipment_id)
    REFERENCES ksx.equipment (enterprise_id, equipment_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_plan ADD CONSTRAINT fk_supplier_inspection_plan_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.supplier_inspection_plan ADD CONSTRAINT fk_supplier_inspection_plan_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.supplier_inspection_plan ADD CONSTRAINT fk_supplier_inspection_plan_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.supplier_inspection_plan ADD CONSTRAINT fk_supplier_inspection_plan_04 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_plan ADD CONSTRAINT fk_supplier_inspection_plan_05 FOREIGN KEY (enterprise_id, project_id)
    REFERENCES ksx.project_master (enterprise_id, project_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_plan ADD CONSTRAINT fk_supplier_inspection_plan_06 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_plan ADD CONSTRAINT fk_supplier_inspection_plan_07 FOREIGN KEY (enterprise_id, purchase_order_id)
    REFERENCES ksx.purchase_order (enterprise_id, purchase_order_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_plan ADD CONSTRAINT fk_supplier_inspection_plan_08 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_plan ADD CONSTRAINT fk_supplier_inspection_plan_09 FOREIGN KEY (enterprise_id, batch_id)
    REFERENCES ksx.batch (enterprise_id, batch_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_application ADD CONSTRAINT fk_supplier_inspection_application_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.supplier_inspection_application ADD CONSTRAINT fk_supplier_inspection_application_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.supplier_inspection_application ADD CONSTRAINT fk_supplier_inspection_application_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.supplier_inspection_application ADD CONSTRAINT fk_supplier_inspection_application_04 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_application ADD CONSTRAINT fk_supplier_inspection_application_05 FOREIGN KEY (enterprise_id, project_id)
    REFERENCES ksx.project_master (enterprise_id, project_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_application ADD CONSTRAINT fk_supplier_inspection_application_06 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_application ADD CONSTRAINT fk_supplier_inspection_application_07 FOREIGN KEY (enterprise_id, purchase_order_id)
    REFERENCES ksx.purchase_order (enterprise_id, purchase_order_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_application ADD CONSTRAINT fk_supplier_inspection_application_08 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_application ADD CONSTRAINT fk_supplier_inspection_application_09 FOREIGN KEY (enterprise_id, batch_id)
    REFERENCES ksx.batch (enterprise_id, batch_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_application ADD CONSTRAINT fk_supplier_inspection_application_10 FOREIGN KEY (enterprise_id, inspection_plan_id, inspection_id)
    REFERENCES ksx.supplier_inspection_plan (enterprise_id, inspection_plan_id, inspection_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_application ADD CONSTRAINT fk_supplier_inspection_application_11 FOREIGN KEY (enterprise_id, application_personnel_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_result ADD CONSTRAINT fk_supplier_inspection_result_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.supplier_inspection_result ADD CONSTRAINT fk_supplier_inspection_result_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.supplier_inspection_result ADD CONSTRAINT fk_supplier_inspection_result_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.supplier_inspection_result ADD CONSTRAINT fk_supplier_inspection_result_04 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_result ADD CONSTRAINT fk_supplier_inspection_result_05 FOREIGN KEY (enterprise_id, project_id)
    REFERENCES ksx.project_master (enterprise_id, project_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_result ADD CONSTRAINT fk_supplier_inspection_result_06 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_result ADD CONSTRAINT fk_supplier_inspection_result_07 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_result ADD CONSTRAINT fk_supplier_inspection_result_08 FOREIGN KEY (enterprise_id, batch_id)
    REFERENCES ksx.batch (enterprise_id, batch_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_result ADD CONSTRAINT fk_supplier_inspection_result_09 FOREIGN KEY (enterprise_id, inspection_plan_id, inspection_id)
    REFERENCES ksx.supplier_inspection_plan (enterprise_id, inspection_plan_id, inspection_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.supplier_inspection_result ADD CONSTRAINT fk_supplier_inspection_result_10 FOREIGN KEY (enterprise_id, inspection_application_id)
    REFERENCES ksx.supplier_inspection_application (enterprise_id, inspection_application_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_request ADD CONSTRAINT fk_corrective_action_request_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.corrective_action_request ADD CONSTRAINT fk_corrective_action_request_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.corrective_action_request ADD CONSTRAINT fk_corrective_action_request_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.corrective_action_request ADD CONSTRAINT fk_corrective_action_request_04 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_request ADD CONSTRAINT fk_corrective_action_request_05 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_request ADD CONSTRAINT fk_corrective_action_request_06 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_request ADD CONSTRAINT fk_corrective_action_request_07 FOREIGN KEY (enterprise_id, batch_id)
    REFERENCES ksx.batch (enterprise_id, batch_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_request ADD CONSTRAINT fk_corrective_action_request_08 FOREIGN KEY (enterprise_id, inspection_application_id)
    REFERENCES ksx.supplier_inspection_application (enterprise_id, inspection_application_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_request ADD CONSTRAINT fk_corrective_action_request_09 FOREIGN KEY (enterprise_id, corrective_action_request_issuer_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_plan ADD CONSTRAINT fk_corrective_action_plan_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.corrective_action_plan ADD CONSTRAINT fk_corrective_action_plan_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.corrective_action_plan ADD CONSTRAINT fk_corrective_action_plan_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.corrective_action_plan ADD CONSTRAINT fk_corrective_action_plan_04 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_plan ADD CONSTRAINT fk_corrective_action_plan_05 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_plan ADD CONSTRAINT fk_corrective_action_plan_06 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_plan ADD CONSTRAINT fk_corrective_action_plan_07 FOREIGN KEY (enterprise_id, batch_id)
    REFERENCES ksx.batch (enterprise_id, batch_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_plan ADD CONSTRAINT fk_corrective_action_plan_08 FOREIGN KEY (enterprise_id, corrective_action_request_id)
    REFERENCES ksx.corrective_action_request (enterprise_id, corrective_action_request_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_plan ADD CONSTRAINT fk_corrective_action_plan_09 FOREIGN KEY (enterprise_id, person_in_charge_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_result ADD CONSTRAINT fk_corrective_action_result_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.corrective_action_result ADD CONSTRAINT fk_corrective_action_result_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.corrective_action_result ADD CONSTRAINT fk_corrective_action_result_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.corrective_action_result ADD CONSTRAINT fk_corrective_action_result_04 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_result ADD CONSTRAINT fk_corrective_action_result_05 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_result ADD CONSTRAINT fk_corrective_action_result_06 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_result ADD CONSTRAINT fk_corrective_action_result_07 FOREIGN KEY (enterprise_id, batch_id)
    REFERENCES ksx.batch (enterprise_id, batch_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_result ADD CONSTRAINT fk_corrective_action_result_08 FOREIGN KEY (enterprise_id, corrective_action_request_id)
    REFERENCES ksx.corrective_action_request (enterprise_id, corrective_action_request_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_result ADD CONSTRAINT fk_corrective_action_result_09 FOREIGN KEY (enterprise_id, corrective_action_plan_id)
    REFERENCES ksx.corrective_action_plan (enterprise_id, corrective_action_plan_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_result ADD CONSTRAINT fk_corrective_action_result_10 FOREIGN KEY (enterprise_id, person_in_charge_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.corrective_action_result ADD CONSTRAINT fk_corrective_action_result_11 FOREIGN KEY (enterprise_id, corrective_action_confirmor_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_packing ADD CONSTRAINT fk_product_packing_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_packing ADD CONSTRAINT fk_product_packing_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_packing ADD CONSTRAINT fk_product_packing_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_packing ADD CONSTRAINT fk_product_packing_04 FOREIGN KEY (enterprise_id, warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_packing ADD CONSTRAINT fk_product_packing_05 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_packing ADD CONSTRAINT fk_product_packing_06 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.equipment_parameter ADD CONSTRAINT fk_equipment_parameter_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.equipment_parameter ADD CONSTRAINT fk_equipment_parameter_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.equipment_parameter ADD CONSTRAINT fk_equipment_parameter_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.equipment_parameter ADD CONSTRAINT fk_equipment_parameter_04 FOREIGN KEY (enterprise_id, equipment_id)
    REFERENCES ksx.equipment (enterprise_id, equipment_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.trace_parameter ADD CONSTRAINT fk_trace_parameter_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.trace_parameter ADD CONSTRAINT fk_trace_parameter_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.trace_parameter ADD CONSTRAINT fk_trace_parameter_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.trace_parameter ADD CONSTRAINT fk_trace_parameter_04 FOREIGN KEY (enterprise_id, equipment_id)
    REFERENCES ksx.equipment (enterprise_id, equipment_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.trace_parameter ADD CONSTRAINT fk_trace_parameter_05 FOREIGN KEY (enterprise_id, parameter_id)
    REFERENCES ksx.equipment_parameter (enterprise_id, parameter_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance ADD CONSTRAINT fk_production_performance_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance ADD CONSTRAINT fk_production_performance_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance ADD CONSTRAINT fk_production_performance_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance ADD CONSTRAINT fk_production_performance_04 FOREIGN KEY (enterprise_id, production_order_id, production_order_sequence)
    REFERENCES ksx.production_order (enterprise_id, production_order_id, production_order_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance ADD CONSTRAINT fk_production_performance_05 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance ADD CONSTRAINT fk_production_performance_06 FOREIGN KEY (enterprise_id, operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance ADD CONSTRAINT fk_production_performance_07 FOREIGN KEY (enterprise_id, routing_id, operation_sequence)
    REFERENCES ksx.routing (enterprise_id, routing_id, operation_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance ADD CONSTRAINT fk_production_performance_08 FOREIGN KEY (enterprise_id, personnel_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance ADD CONSTRAINT fk_production_performance_09 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance ADD CONSTRAINT fk_production_performance_10 FOREIGN KEY (enterprise_id, batch_id)
    REFERENCES ksx.batch (enterprise_id, batch_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_item ADD CONSTRAINT fk_production_performance_item_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_item ADD CONSTRAINT fk_production_performance_item_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_item ADD CONSTRAINT fk_production_performance_item_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_item ADD CONSTRAINT fk_production_performance_item_04 FOREIGN KEY (enterprise_id, production_performance_id, production_performance_sequence)
    REFERENCES ksx.production_performance (enterprise_id, production_performance_id, production_performance_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_item ADD CONSTRAINT fk_production_performance_item_05 FOREIGN KEY (enterprise_id, production_order_id, production_order_sequence)
    REFERENCES ksx.production_order (enterprise_id, production_order_id, production_order_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_item ADD CONSTRAINT fk_production_performance_item_06 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_item ADD CONSTRAINT fk_production_performance_item_07 FOREIGN KEY (enterprise_id, line_id)
    REFERENCES ksx.line (enterprise_id, line_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_item ADD CONSTRAINT fk_production_performance_item_08 FOREIGN KEY (enterprise_id, operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_item ADD CONSTRAINT fk_production_performance_item_09 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_item ADD CONSTRAINT fk_production_performance_item_10 FOREIGN KEY (enterprise_id, replacement_child_item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_item ADD CONSTRAINT fk_production_performance_item_11 FOREIGN KEY (enterprise_id, warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_personnel ADD CONSTRAINT fk_production_performance_personnel_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_personnel ADD CONSTRAINT fk_production_performance_personnel_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_personnel ADD CONSTRAINT fk_production_performance_personnel_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_personnel ADD CONSTRAINT fk_production_performance_personnel_04 FOREIGN KEY (enterprise_id, production_performance_id, production_performance_sequence)
    REFERENCES ksx.production_performance (enterprise_id, production_performance_id, production_performance_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_personnel ADD CONSTRAINT fk_production_performance_personnel_05 FOREIGN KEY (enterprise_id, production_order_id, production_order_sequence)
    REFERENCES ksx.production_order (enterprise_id, production_order_id, production_order_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_personnel ADD CONSTRAINT fk_production_performance_personnel_06 FOREIGN KEY (enterprise_id, operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_personnel ADD CONSTRAINT fk_production_performance_personnel_07 FOREIGN KEY (enterprise_id, personnel_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_equipment ADD CONSTRAINT fk_production_performance_equipment_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_equipment ADD CONSTRAINT fk_production_performance_equipment_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_equipment ADD CONSTRAINT fk_production_performance_equipment_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_equipment ADD CONSTRAINT fk_production_performance_equipment_04 FOREIGN KEY (enterprise_id, production_performance_id, production_performance_sequence)
    REFERENCES ksx.production_performance (enterprise_id, production_performance_id, production_performance_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_equipment ADD CONSTRAINT fk_production_performance_equipment_05 FOREIGN KEY (enterprise_id, production_order_id, production_order_sequence)
    REFERENCES ksx.production_order (enterprise_id, production_order_id, production_order_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_equipment ADD CONSTRAINT fk_production_performance_equipment_06 FOREIGN KEY (enterprise_id, operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_equipment ADD CONSTRAINT fk_production_performance_equipment_07 FOREIGN KEY (enterprise_id, routing_id, operation_sequence)
    REFERENCES ksx.routing (enterprise_id, routing_id, operation_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_equipment ADD CONSTRAINT fk_production_performance_equipment_08 FOREIGN KEY (enterprise_id, personnel_id)
    REFERENCES ksx.personnel (enterprise_id, personnel_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_equipment ADD CONSTRAINT fk_production_performance_equipment_09 FOREIGN KEY (enterprise_id, equipment_id)
    REFERENCES ksx.equipment (enterprise_id, equipment_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_quality ADD CONSTRAINT fk_production_performance_quality_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_quality ADD CONSTRAINT fk_production_performance_quality_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_quality ADD CONSTRAINT fk_production_performance_quality_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.production_performance_quality ADD CONSTRAINT fk_production_performance_quality_04 FOREIGN KEY (enterprise_id, production_performance_id, production_performance_sequence)
    REFERENCES ksx.production_performance (enterprise_id, production_performance_id, production_performance_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_quality ADD CONSTRAINT fk_production_performance_quality_05 FOREIGN KEY (enterprise_id, production_order_id, production_order_sequence)
    REFERENCES ksx.production_order (enterprise_id, production_order_id, production_order_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_quality ADD CONSTRAINT fk_production_performance_quality_06 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_quality ADD CONSTRAINT fk_production_performance_quality_07 FOREIGN KEY (enterprise_id, operation_id)
    REFERENCES ksx.operation (enterprise_id, operation_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_quality ADD CONSTRAINT fk_production_performance_quality_08 FOREIGN KEY (enterprise_id, routing_id, operation_sequence)
    REFERENCES ksx.routing (enterprise_id, routing_id, operation_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_quality ADD CONSTRAINT fk_production_performance_quality_09 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.production_performance_quality ADD CONSTRAINT fk_production_performance_quality_10 FOREIGN KEY (enterprise_id, batch_id)
    REFERENCES ksx.batch (enterprise_id, batch_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.inventory ADD CONSTRAINT fk_inventory_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.inventory ADD CONSTRAINT fk_inventory_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.inventory ADD CONSTRAINT fk_inventory_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.inventory ADD CONSTRAINT fk_inventory_04 FOREIGN KEY (enterprise_id, warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.inventory ADD CONSTRAINT fk_inventory_05 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.available_inventory ADD CONSTRAINT fk_available_inventory_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.available_inventory ADD CONSTRAINT fk_available_inventory_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.available_inventory ADD CONSTRAINT fk_available_inventory_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.available_inventory ADD CONSTRAINT fk_available_inventory_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.stock_transfer ADD CONSTRAINT fk_stock_transfer_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.stock_transfer ADD CONSTRAINT fk_stock_transfer_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.stock_transfer ADD CONSTRAINT fk_stock_transfer_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.stock_transfer ADD CONSTRAINT fk_stock_transfer_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.stock_transfer ADD CONSTRAINT fk_stock_transfer_05 FOREIGN KEY (enterprise_id, warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.stock_transfer ADD CONSTRAINT fk_stock_transfer_06 FOREIGN KEY (enterprise_id, receipt_warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.inventory_count ADD CONSTRAINT fk_inventory_count_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.inventory_count ADD CONSTRAINT fk_inventory_count_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.inventory_count ADD CONSTRAINT fk_inventory_count_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.inventory_count ADD CONSTRAINT fk_inventory_count_04 FOREIGN KEY (enterprise_id, warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.inventory_count ADD CONSTRAINT fk_inventory_count_05 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_incoming ADD CONSTRAINT fk_product_incoming_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_incoming ADD CONSTRAINT fk_product_incoming_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_incoming ADD CONSTRAINT fk_product_incoming_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_incoming ADD CONSTRAINT fk_product_incoming_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_incoming ADD CONSTRAINT fk_product_incoming_05 FOREIGN KEY (enterprise_id, customer_id)
    REFERENCES ksx.customer_party_master (enterprise_id, customer_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_incoming ADD CONSTRAINT fk_product_incoming_06 FOREIGN KEY (enterprise_id, warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_incoming ADD CONSTRAINT fk_product_incoming_07 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_release_request ADD CONSTRAINT fk_product_release_request_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_release_request ADD CONSTRAINT fk_product_release_request_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_release_request ADD CONSTRAINT fk_product_release_request_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_release_request ADD CONSTRAINT fk_product_release_request_04 FOREIGN KEY (enterprise_id, line_id)
    REFERENCES ksx.line (enterprise_id, line_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_release_request ADD CONSTRAINT fk_product_release_request_05 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_release_request ADD CONSTRAINT fk_product_release_request_06 FOREIGN KEY (enterprise_id, warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_release_request ADD CONSTRAINT fk_product_release_request_07 FOREIGN KEY (enterprise_id, sales_document_number, sales_document_sequence)
    REFERENCES ksx.sales_order (enterprise_id, sales_document_number, sales_document_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조: 대체키(문서번호+순번) 참조
ALTER TABLE ksx.product_release_request ADD CONSTRAINT fk_product_release_request_08 FOREIGN KEY (enterprise_id, customer_id)
    REFERENCES ksx.customer_party_master (enterprise_id, customer_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_release_request_header ADD CONSTRAINT fk_product_release_request_header_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_release_request_header ADD CONSTRAINT fk_product_release_request_header_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_release_request_header ADD CONSTRAINT fk_product_release_request_header_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_release ADD CONSTRAINT fk_product_release_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_release ADD CONSTRAINT fk_product_release_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_release ADD CONSTRAINT fk_product_release_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_release ADD CONSTRAINT fk_product_release_04 FOREIGN KEY (enterprise_id, product_release_request_id)
    REFERENCES ksx.product_release_request_header (enterprise_id, product_release_request_id) DEFERRABLE INITIALLY DEFERRED; -- 헤더 참조: 출하의뢰 문서 전체 참조(표 74 개정): 출하의뢰 행과는 품목식별자·수주문서순번으로 대응 — 헤더 테이블 ProductReleaseRequestHeader 경유 FK
ALTER TABLE ksx.product_release ADD CONSTRAINT fk_product_release_05 FOREIGN KEY (enterprise_id, sales_document_number, sales_document_sequence)
    REFERENCES ksx.sales_order (enterprise_id, sales_document_number, sales_document_sequence) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조: 대체키(문서번호+순번) 참조
ALTER TABLE ksx.product_release ADD CONSTRAINT fk_product_release_06 FOREIGN KEY (enterprise_id, line_id)
    REFERENCES ksx.line (enterprise_id, line_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_release ADD CONSTRAINT fk_product_release_07 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_release ADD CONSTRAINT fk_product_release_08 FOREIGN KEY (enterprise_id, customer_id)
    REFERENCES ksx.customer_party_master (enterprise_id, customer_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_release ADD CONSTRAINT fk_product_release_09 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_release ADD CONSTRAINT fk_product_release_10 FOREIGN KEY (enterprise_id, warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx."return" ADD CONSTRAINT fk_return_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx."return" ADD CONSTRAINT fk_return_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx."return" ADD CONSTRAINT fk_return_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx."return" ADD CONSTRAINT fk_return_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx."return" ADD CONSTRAINT fk_return_05 FOREIGN KEY (enterprise_id, lot_id)
    REFERENCES ksx.lot (enterprise_id, lot_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx."return" ADD CONSTRAINT fk_return_06 FOREIGN KEY (enterprise_id, batch_id)
    REFERENCES ksx.batch (enterprise_id, batch_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx."return" ADD CONSTRAINT fk_return_07 FOREIGN KEY (enterprise_id, warehouse_id)
    REFERENCES ksx.warehouse_location (enterprise_id, warehouse_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx."return" ADD CONSTRAINT fk_return_08 FOREIGN KEY (enterprise_id, customer_id)
    REFERENCES ksx.customer_party_master (enterprise_id, customer_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx."return" ADD CONSTRAINT fk_return_09 FOREIGN KEY (enterprise_id, vendor_id)
    REFERENCES ksx.vendor_party_master (enterprise_id, vendor_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.product_trace_parameter_on_customer ADD CONSTRAINT fk_product_trace_parameter_on_customer_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_trace_parameter_on_customer ADD CONSTRAINT fk_product_trace_parameter_on_customer_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_trace_parameter_on_customer ADD CONSTRAINT fk_product_trace_parameter_on_customer_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.product_trace_parameter_on_customer ADD CONSTRAINT fk_product_trace_parameter_on_customer_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.after_sales_service_request ADD CONSTRAINT fk_after_sales_service_request_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.after_sales_service_request ADD CONSTRAINT fk_after_sales_service_request_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.after_sales_service_request ADD CONSTRAINT fk_after_sales_service_request_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.after_sales_service_request ADD CONSTRAINT fk_after_sales_service_request_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.after_sales_service_request_result ADD CONSTRAINT fk_after_sales_service_request_result_01 FOREIGN KEY (enterprise_id)
    REFERENCES ksx.enterprise (enterprise_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.after_sales_service_request_result ADD CONSTRAINT fk_after_sales_service_request_result_02 FOREIGN KEY (enterprise_id, site_id)
    REFERENCES ksx.site (enterprise_id, site_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.after_sales_service_request_result ADD CONSTRAINT fk_after_sales_service_request_result_03 FOREIGN KEY (enterprise_id, plant_id)
    REFERENCES ksx.plant (enterprise_id, plant_id) DEFERRABLE INITIALLY DEFERRED; -- 기본 속성:
ALTER TABLE ksx.after_sales_service_request_result ADD CONSTRAINT fk_after_sales_service_request_result_04 FOREIGN KEY (enterprise_id, item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.after_sales_service_request_result ADD CONSTRAINT fk_after_sales_service_request_result_05 FOREIGN KEY (enterprise_id, request_number)
    REFERENCES ksx.after_sales_service_request (enterprise_id, request_number) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.after_sales_service_request_result ADD CONSTRAINT fk_after_sales_service_request_result_06 FOREIGN KEY (enterprise_id, child_item_id)
    REFERENCES ksx.item_master (enterprise_id, item_id) DEFERRABLE INITIALLY DEFERRED; -- 명사 참조:
ALTER TABLE ksx.routing ADD CONSTRAINT fk_routing_06 FOREIGN KEY (enterprise_id, routing_id)
    REFERENCES ksx.routing_header (enterprise_id, routing_id) DEFERRABLE INITIALLY DEFERRED; -- 헤더-라인: 공정경로 행은 같은 RoutingID의 헤더 행을 참조
ALTER TABLE ksx.bom ADD CONSTRAINT fk_bom_07 FOREIGN KEY (enterprise_id, bom_id, bom_revision_number)
    REFERENCES ksx.bom_header (enterprise_id, bom_id, bom_revision_number) DEFERRABLE INITIALLY DEFERRED; -- 헤더-라인: 자재명세서 행은 같은 BOMID+BOMRevisionNumber의 헤더 행을 참조
ALTER TABLE ksx.product_release_request ADD CONSTRAINT fk_product_release_request_09 FOREIGN KEY (enterprise_id, product_release_request_id)
    REFERENCES ksx.product_release_request_header (enterprise_id, product_release_request_id) DEFERRABLE INITIALLY DEFERRED; -- 헤더-라인: 출하의뢰 행은 같은 ProductReleaseRequestID의 헤더 행을 참조

-- FK 로 옮기지 않은 관계 (SHACL·애플리케이션 검증 대상)
--   TransferCommand.SourceID → Operation / Equipment / StockerInventory / Carrier [다형 참조] 출발지·목적지유형 등으로 대상 명사를 구분 — 물리 FK 제약 대신 애플리케이션 검증
--   TransferCommand.DestinationID → Operation / Equipment / StockerInventory / Carrier [다형 참조] 출발지·목적지유형 등으로 대상 명사를 구분 — 물리 FK 제약 대신 애플리케이션 검증
--   TransferStart.DestinationID → Operation / Equipment / StockerInventory / Carrier [다형 참조] 출발지·목적지유형 등으로 대상 명사를 구분 — 물리 FK 제약 대신 애플리케이션 검증
--   TransferEnd.DestinationID → Operation / Equipment / StockerInventory / Carrier [다형 참조] 출발지·목적지유형 등으로 대상 명사를 구분 — 물리 FK 제약 대신 애플리케이션 검증
--   ProductionPerformanceItem.EnterpriseID, WarehouseID, WarehouseSection → WarehouseLocation [하위 목록 참조] 창고섹션은 창고의 WarehouseSectionList 항목을 가리킴 — 물리 FK 불가, 섹션 테이블 분리 검토
--   ProductTraceParameterOnCustomer.SerialNumber → 고객 설치 제품(제조번호 단위) [표준 외 대상] 확장 명사(KS X 9101-2 절차) 정의 후 연결
--   AfterSalesServiceRequest.SerialNumber → 고객 설치 제품(제조번호 단위) [표준 외 대상] 확장 명사(KS X 9101-2 절차) 정의 후 연결
--   AfterSalesServiceRequestResult.SerialNumber → 고객 설치 제품(제조번호 단위) [표준 외 대상] 확장 명사(KS X 9101-2 절차) 정의 후 연결
-- 등록자·수정자(CreatorID·ModifierID → Personnel) 140건도 FK 로 만들지 않는다 (리뷰 F12).
--   ERP·HR·EAP 의 등록자 ID 는 MES 사원 마스터에 없는 경우가 흔해 배치 커밋이 실패한다. SHACL 경고로만 검증한다.

-- FK 컬럼 인덱스. 생략: EnterpriseID 단독(PK 선두와 겹침), 사업장·공장(선택도 낮음, 리뷰 F12)
CREATE INDEX IF NOT EXISTS ix_department_04 ON ksx.department (enterprise_id, parent_department_id);
CREATE INDEX IF NOT EXISTS ix_personnel_04 ON ksx.personnel (enterprise_id, department_id);
CREATE INDEX IF NOT EXISTS ix_common_code_master_04 ON ksx.common_code_master (enterprise_id, parent_common_code_group, parent_common_code_id);
CREATE INDEX IF NOT EXISTS ix_item_master_04 ON ksx.item_master (enterprise_id, main_customer_id);
CREATE INDEX IF NOT EXISTS ix_item_master_05 ON ksx.item_master (enterprise_id, main_vendor_id);
CREATE INDEX IF NOT EXISTS ix_item_master_06 ON ksx.item_master (enterprise_id, receipt_warehouse_id);
CREATE INDEX IF NOT EXISTS ix_item_master_07 ON ksx.item_master (enterprise_id, issue_warehouse_id);
CREATE INDEX IF NOT EXISTS ix_item_master_08 ON ksx.item_master (enterprise_id, replacement_item_id);
CREATE INDEX IF NOT EXISTS ix_bom_04 ON ksx.bom (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_bom_05 ON ksx.bom (enterprise_id, child_item_id);
CREATE INDEX IF NOT EXISTS ix_bom_06 ON ksx.bom (enterprise_id, routing_id, operation_sequence);
CREATE INDEX IF NOT EXISTS ix_lot_04 ON ksx.lot (enterprise_id, parent_lot_id);
CREATE INDEX IF NOT EXISTS ix_lot_05 ON ksx.lot (enterprise_id, child_lot_id);
CREATE INDEX IF NOT EXISTS ix_lot_06 ON ksx.lot (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_lot_07 ON ksx.lot (enterprise_id, carrier_id);
CREATE INDEX IF NOT EXISTS ix_lot_08 ON ksx.lot (enterprise_id, production_order_id, production_order_sequence);
CREATE INDEX IF NOT EXISTS ix_lot_09 ON ksx.lot (enterprise_id, current_operation_id);
CREATE INDEX IF NOT EXISTS ix_lot_10 ON ksx.lot (enterprise_id, next_operation_id);
CREATE INDEX IF NOT EXISTS ix_lot_11 ON ksx.lot (enterprise_id, personnel_id);
CREATE INDEX IF NOT EXISTS ix_routing_04 ON ksx.routing (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_routing_05 ON ksx.routing (enterprise_id, operation_id);
CREATE INDEX IF NOT EXISTS ix_equipment_04 ON ksx.equipment (enterprise_id, parent_equipment_id);
CREATE INDEX IF NOT EXISTS ix_equipment_05 ON ksx.equipment (enterprise_id, department_in_charge_id);
CREATE INDEX IF NOT EXISTS ix_equipment_06 ON ksx.equipment (enterprise_id, person_in_charge_id);
CREATE INDEX IF NOT EXISTS ix_equipment_07 ON ksx.equipment (enterprise_id, operation_id);
CREATE INDEX IF NOT EXISTS ix_operation_equipment_04 ON ksx.operation_equipment (enterprise_id, operation_id);
CREATE INDEX IF NOT EXISTS ix_operation_equipment_05 ON ksx.operation_equipment (enterprise_id, equipment_id);
CREATE INDEX IF NOT EXISTS ix_stocker_inventory_04 ON ksx.stocker_inventory (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_stocker_inventory_05 ON ksx.stocker_inventory (enterprise_id, carrier_id);
CREATE INDEX IF NOT EXISTS ix_stocker_inventory_06 ON ksx.stocker_inventory (enterprise_id, alternate_stocker_id);
CREATE INDEX IF NOT EXISTS ix_batch_04 ON ksx.batch (enterprise_id, parent_batch_id);
CREATE INDEX IF NOT EXISTS ix_batch_05 ON ksx.batch (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_batch_06 ON ksx.batch (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_batch_07 ON ksx.batch (enterprise_id, production_order_id, production_order_sequence);
CREATE INDEX IF NOT EXISTS ix_batch_08 ON ksx.batch (enterprise_id, bom_id, bom_revision_number);
CREATE INDEX IF NOT EXISTS ix_batch_09 ON ksx.batch (enterprise_id, operation_id);
CREATE INDEX IF NOT EXISTS ix_batch_10 ON ksx.batch (enterprise_id, equipment_id);
CREATE INDEX IF NOT EXISTS ix_batch_11 ON ksx.batch (enterprise_id, personnel_id);
CREATE INDEX IF NOT EXISTS ix_line_04 ON ksx.line (enterprise_id, parent_line_id);
CREATE INDEX IF NOT EXISTS ix_line_05 ON ksx.line (enterprise_id, department_in_charge_id);
CREATE INDEX IF NOT EXISTS ix_line_06 ON ksx.line (enterprise_id, person_in_charge_id);
CREATE INDEX IF NOT EXISTS ix_line_07 ON ksx.line (enterprise_id, calendar_id);
CREATE INDEX IF NOT EXISTS ix_line_08 ON ksx.line (enterprise_id, issue_warehouse_id);
CREATE INDEX IF NOT EXISTS ix_line_09 ON ksx.line (enterprise_id, receipt_warehouse_id);
CREATE INDEX IF NOT EXISTS ix_enterprise_01 ON ksx.enterprise (parent_enterprise_id);
CREATE INDEX IF NOT EXISTS ix_project_master_04 ON ksx.project_master (enterprise_id, responsible_department_id);
CREATE INDEX IF NOT EXISTS ix_project_master_05 ON ksx.project_master (enterprise_id, person_in_charge_id);
CREATE INDEX IF NOT EXISTS ix_project_master_06 ON ksx.project_master (enterprise_id, sales_document_number, sales_document_sequence);
CREATE INDEX IF NOT EXISTS ix_project_master_07 ON ksx.project_master (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_project_master_08 ON ksx.project_master (enterprise_id, division_id);
CREATE INDEX IF NOT EXISTS ix_engineering_change_order_04 ON ksx.engineering_change_order (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_engineering_change_order_05 ON ksx.engineering_change_order (enterprise_id, bom_id, bom_revision_number, child_item_id);
CREATE INDEX IF NOT EXISTS ix_engineering_change_order_06 ON ksx.engineering_change_order (enterprise_id, child_item_id);
CREATE INDEX IF NOT EXISTS ix_sales_order_04 ON ksx.sales_order (enterprise_id, customer_id);
CREATE INDEX IF NOT EXISTS ix_sales_order_05 ON ksx.sales_order (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_sales_plan_04 ON ksx.sales_plan (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_base_price_04 ON ksx.base_price (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_purchase_requisition_04 ON ksx.purchase_requisition (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_purchase_requisition_05 ON ksx.purchase_requisition (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_purchase_requisition_06 ON ksx.purchase_requisition (enterprise_id, requester_department_id);
CREATE INDEX IF NOT EXISTS ix_purchase_requisition_07 ON ksx.purchase_requisition (enterprise_id, requester_personnel_id);
CREATE INDEX IF NOT EXISTS ix_purchase_order_04 ON ksx.purchase_order (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_purchase_order_05 ON ksx.purchase_order (enterprise_id, personnel_id);
CREATE INDEX IF NOT EXISTS ix_purchase_order_06 ON ksx.purchase_order (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_material_arrival_04 ON ksx.material_arrival (enterprise_id, purchase_document_number, purchase_document_sequence);
CREATE INDEX IF NOT EXISTS ix_material_arrival_05 ON ksx.material_arrival (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_material_arrival_06 ON ksx.material_arrival (enterprise_id, receipt_warehouse_id);
CREATE INDEX IF NOT EXISTS ix_material_arrival_07 ON ksx.material_arrival (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_material_arrival_08 ON ksx.material_arrival (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_goods_receipt_04 ON ksx.goods_receipt (enterprise_id, warehouse_id);
CREATE INDEX IF NOT EXISTS ix_goods_receipt_05 ON ksx.goods_receipt (enterprise_id, personnel_id);
CREATE INDEX IF NOT EXISTS ix_goods_receipt_06 ON ksx.goods_receipt (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_goods_receipt_07 ON ksx.goods_receipt (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_goods_issue_04 ON ksx.goods_issue (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_goods_issue_05 ON ksx.goods_issue (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_goods_issue_06 ON ksx.goods_issue (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_goods_issue_07 ON ksx.goods_issue (enterprise_id, warehouse_id);
CREATE INDEX IF NOT EXISTS ix_production_planning_04 ON ksx.production_planning (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_production_order_04 ON ksx.production_order (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_production_order_05 ON ksx.production_order (enterprise_id, line_id);
CREATE INDEX IF NOT EXISTS ix_production_order_06 ON ksx.production_order (enterprise_id, routing_id);
CREATE INDEX IF NOT EXISTS ix_production_order_07 ON ksx.production_order (enterprise_id, bom_id, bom_revision_number);
CREATE INDEX IF NOT EXISTS ix_production_order_08 ON ksx.production_order (enterprise_id, sales_document_number, sales_document_sequence);
CREATE INDEX IF NOT EXISTS ix_operation_start_04 ON ksx.operation_start (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_operation_start_05 ON ksx.operation_start (enterprise_id, operation_id);
CREATE INDEX IF NOT EXISTS ix_operation_start_06 ON ksx.operation_start (enterprise_id, equipment_id);
CREATE INDEX IF NOT EXISTS ix_operation_start_07 ON ksx.operation_start (enterprise_id, personnel_id);
CREATE INDEX IF NOT EXISTS ix_operation_end_04 ON ksx.operation_end (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_operation_end_05 ON ksx.operation_end (enterprise_id, operation_id);
CREATE INDEX IF NOT EXISTS ix_operation_end_06 ON ksx.operation_end (enterprise_id, equipment_id);
CREATE INDEX IF NOT EXISTS ix_operation_end_07 ON ksx.operation_end (enterprise_id, personnel_id);
CREATE INDEX IF NOT EXISTS ix_transfer_command_04 ON ksx.transfer_command (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_transfer_command_05 ON ksx.transfer_command (enterprise_id, carrier_id);
CREATE INDEX IF NOT EXISTS ix_transfer_start_04 ON ksx.transfer_start (enterprise_id, transfer_command_id);
CREATE INDEX IF NOT EXISTS ix_transfer_start_05 ON ksx.transfer_start (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_transfer_start_06 ON ksx.transfer_start (enterprise_id, carrier_id);
CREATE INDEX IF NOT EXISTS ix_transfer_end_04 ON ksx.transfer_end (enterprise_id, transfer_command_id);
CREATE INDEX IF NOT EXISTS ix_transfer_end_05 ON ksx.transfer_end (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_transfer_end_06 ON ksx.transfer_end (enterprise_id, carrier_id);
CREATE INDEX IF NOT EXISTS ix_in_transit_location_04 ON ksx.in_transit_location (enterprise_id, transfer_command_id);
CREATE INDEX IF NOT EXISTS ix_in_transit_location_05 ON ksx.in_transit_location (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_in_transit_location_06 ON ksx.in_transit_location (enterprise_id, carrier_id);
CREATE INDEX IF NOT EXISTS ix_equipment_state_04 ON ksx.equipment_state (enterprise_id, equipment_id);
CREATE INDEX IF NOT EXISTS ix_equipment_state_05 ON ksx.equipment_state (enterprise_id, last_processed_lot_id);
CREATE INDEX IF NOT EXISTS ix_equipment_state_06 ON ksx.equipment_state (enterprise_id, last_processed_operation_id);
CREATE INDEX IF NOT EXISTS ix_alarm_04 ON ksx.alarm (enterprise_id, equipment_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_plan_04 ON ksx.supplier_inspection_plan (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_plan_05 ON ksx.supplier_inspection_plan (enterprise_id, project_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_plan_06 ON ksx.supplier_inspection_plan (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_plan_07 ON ksx.supplier_inspection_plan (enterprise_id, purchase_order_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_plan_08 ON ksx.supplier_inspection_plan (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_plan_09 ON ksx.supplier_inspection_plan (enterprise_id, batch_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_application_04 ON ksx.supplier_inspection_application (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_application_05 ON ksx.supplier_inspection_application (enterprise_id, project_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_application_06 ON ksx.supplier_inspection_application (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_application_07 ON ksx.supplier_inspection_application (enterprise_id, purchase_order_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_application_08 ON ksx.supplier_inspection_application (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_application_09 ON ksx.supplier_inspection_application (enterprise_id, batch_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_application_10 ON ksx.supplier_inspection_application (enterprise_id, inspection_plan_id, inspection_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_application_11 ON ksx.supplier_inspection_application (enterprise_id, application_personnel_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_result_04 ON ksx.supplier_inspection_result (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_result_05 ON ksx.supplier_inspection_result (enterprise_id, project_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_result_06 ON ksx.supplier_inspection_result (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_result_07 ON ksx.supplier_inspection_result (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_result_08 ON ksx.supplier_inspection_result (enterprise_id, batch_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_result_09 ON ksx.supplier_inspection_result (enterprise_id, inspection_plan_id, inspection_id);
CREATE INDEX IF NOT EXISTS ix_supplier_inspection_result_10 ON ksx.supplier_inspection_result (enterprise_id, inspection_application_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_request_04 ON ksx.corrective_action_request (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_request_05 ON ksx.corrective_action_request (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_request_06 ON ksx.corrective_action_request (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_request_07 ON ksx.corrective_action_request (enterprise_id, batch_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_request_08 ON ksx.corrective_action_request (enterprise_id, inspection_application_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_request_09 ON ksx.corrective_action_request (enterprise_id, corrective_action_request_issuer_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_plan_04 ON ksx.corrective_action_plan (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_plan_05 ON ksx.corrective_action_plan (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_plan_06 ON ksx.corrective_action_plan (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_plan_07 ON ksx.corrective_action_plan (enterprise_id, batch_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_plan_08 ON ksx.corrective_action_plan (enterprise_id, corrective_action_request_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_plan_09 ON ksx.corrective_action_plan (enterprise_id, person_in_charge_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_result_04 ON ksx.corrective_action_result (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_result_05 ON ksx.corrective_action_result (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_result_06 ON ksx.corrective_action_result (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_result_07 ON ksx.corrective_action_result (enterprise_id, batch_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_result_08 ON ksx.corrective_action_result (enterprise_id, corrective_action_request_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_result_09 ON ksx.corrective_action_result (enterprise_id, corrective_action_plan_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_result_10 ON ksx.corrective_action_result (enterprise_id, person_in_charge_id);
CREATE INDEX IF NOT EXISTS ix_corrective_action_result_11 ON ksx.corrective_action_result (enterprise_id, corrective_action_confirmor_id);
CREATE INDEX IF NOT EXISTS ix_product_packing_04 ON ksx.product_packing (enterprise_id, warehouse_id);
CREATE INDEX IF NOT EXISTS ix_product_packing_05 ON ksx.product_packing (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_product_packing_06 ON ksx.product_packing (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_equipment_parameter_04 ON ksx.equipment_parameter (enterprise_id, equipment_id);
CREATE INDEX IF NOT EXISTS ix_trace_parameter_04 ON ksx.trace_parameter (enterprise_id, equipment_id);
CREATE INDEX IF NOT EXISTS ix_trace_parameter_05 ON ksx.trace_parameter (enterprise_id, parameter_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_04 ON ksx.production_performance (enterprise_id, production_order_id, production_order_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_05 ON ksx.production_performance (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_06 ON ksx.production_performance (enterprise_id, operation_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_07 ON ksx.production_performance (enterprise_id, routing_id, operation_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_08 ON ksx.production_performance (enterprise_id, personnel_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_09 ON ksx.production_performance (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_10 ON ksx.production_performance (enterprise_id, batch_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_item_04 ON ksx.production_performance_item (enterprise_id, production_performance_id, production_performance_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_item_05 ON ksx.production_performance_item (enterprise_id, production_order_id, production_order_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_item_06 ON ksx.production_performance_item (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_item_07 ON ksx.production_performance_item (enterprise_id, line_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_item_08 ON ksx.production_performance_item (enterprise_id, operation_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_item_09 ON ksx.production_performance_item (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_item_10 ON ksx.production_performance_item (enterprise_id, replacement_child_item_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_item_11 ON ksx.production_performance_item (enterprise_id, warehouse_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_personnel_04 ON ksx.production_performance_personnel (enterprise_id, production_performance_id, production_performance_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_personnel_05 ON ksx.production_performance_personnel (enterprise_id, production_order_id, production_order_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_personnel_06 ON ksx.production_performance_personnel (enterprise_id, operation_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_personnel_07 ON ksx.production_performance_personnel (enterprise_id, personnel_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_equipment_04 ON ksx.production_performance_equipment (enterprise_id, production_performance_id, production_performance_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_equipment_05 ON ksx.production_performance_equipment (enterprise_id, production_order_id, production_order_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_equipment_06 ON ksx.production_performance_equipment (enterprise_id, operation_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_equipment_07 ON ksx.production_performance_equipment (enterprise_id, routing_id, operation_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_equipment_08 ON ksx.production_performance_equipment (enterprise_id, personnel_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_equipment_09 ON ksx.production_performance_equipment (enterprise_id, equipment_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_quality_04 ON ksx.production_performance_quality (enterprise_id, production_performance_id, production_performance_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_quality_05 ON ksx.production_performance_quality (enterprise_id, production_order_id, production_order_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_quality_06 ON ksx.production_performance_quality (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_quality_07 ON ksx.production_performance_quality (enterprise_id, operation_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_quality_08 ON ksx.production_performance_quality (enterprise_id, routing_id, operation_sequence);
CREATE INDEX IF NOT EXISTS ix_production_performance_quality_09 ON ksx.production_performance_quality (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_production_performance_quality_10 ON ksx.production_performance_quality (enterprise_id, batch_id);
CREATE INDEX IF NOT EXISTS ix_inventory_04 ON ksx.inventory (enterprise_id, warehouse_id);
CREATE INDEX IF NOT EXISTS ix_inventory_05 ON ksx.inventory (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_available_inventory_04 ON ksx.available_inventory (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_stock_transfer_04 ON ksx.stock_transfer (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_stock_transfer_05 ON ksx.stock_transfer (enterprise_id, warehouse_id);
CREATE INDEX IF NOT EXISTS ix_stock_transfer_06 ON ksx.stock_transfer (enterprise_id, receipt_warehouse_id);
CREATE INDEX IF NOT EXISTS ix_inventory_count_04 ON ksx.inventory_count (enterprise_id, warehouse_id);
CREATE INDEX IF NOT EXISTS ix_inventory_count_05 ON ksx.inventory_count (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_product_incoming_04 ON ksx.product_incoming (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_product_incoming_05 ON ksx.product_incoming (enterprise_id, customer_id);
CREATE INDEX IF NOT EXISTS ix_product_incoming_06 ON ksx.product_incoming (enterprise_id, warehouse_id);
CREATE INDEX IF NOT EXISTS ix_product_incoming_07 ON ksx.product_incoming (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_product_release_request_04 ON ksx.product_release_request (enterprise_id, line_id);
CREATE INDEX IF NOT EXISTS ix_product_release_request_05 ON ksx.product_release_request (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_product_release_request_06 ON ksx.product_release_request (enterprise_id, warehouse_id);
CREATE INDEX IF NOT EXISTS ix_product_release_request_07 ON ksx.product_release_request (enterprise_id, sales_document_number, sales_document_sequence);
CREATE INDEX IF NOT EXISTS ix_product_release_request_08 ON ksx.product_release_request (enterprise_id, customer_id);
CREATE INDEX IF NOT EXISTS ix_product_release_04 ON ksx.product_release (enterprise_id, product_release_request_id);
CREATE INDEX IF NOT EXISTS ix_product_release_05 ON ksx.product_release (enterprise_id, sales_document_number, sales_document_sequence);
CREATE INDEX IF NOT EXISTS ix_product_release_06 ON ksx.product_release (enterprise_id, line_id);
CREATE INDEX IF NOT EXISTS ix_product_release_07 ON ksx.product_release (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_product_release_08 ON ksx.product_release (enterprise_id, customer_id);
CREATE INDEX IF NOT EXISTS ix_product_release_09 ON ksx.product_release (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_product_release_10 ON ksx.product_release (enterprise_id, warehouse_id);
CREATE INDEX IF NOT EXISTS ix_return_04 ON ksx."return" (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_return_05 ON ksx."return" (enterprise_id, lot_id);
CREATE INDEX IF NOT EXISTS ix_return_06 ON ksx."return" (enterprise_id, batch_id);
CREATE INDEX IF NOT EXISTS ix_return_07 ON ksx."return" (enterprise_id, warehouse_id);
CREATE INDEX IF NOT EXISTS ix_return_08 ON ksx."return" (enterprise_id, customer_id);
CREATE INDEX IF NOT EXISTS ix_return_09 ON ksx."return" (enterprise_id, vendor_id);
CREATE INDEX IF NOT EXISTS ix_product_trace_parameter_on_customer_04 ON ksx.product_trace_parameter_on_customer (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_after_sales_service_request_04 ON ksx.after_sales_service_request (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_after_sales_service_request_result_04 ON ksx.after_sales_service_request_result (enterprise_id, item_id);
CREATE INDEX IF NOT EXISTS ix_after_sales_service_request_result_05 ON ksx.after_sales_service_request_result (enterprise_id, request_number);
CREATE INDEX IF NOT EXISTS ix_after_sales_service_request_result_06 ON ksx.after_sales_service_request_result (enterprise_id, child_item_id);
CREATE INDEX IF NOT EXISTS ix_routing_06 ON ksx.routing (enterprise_id, routing_id);
CREATE INDEX IF NOT EXISTS ix_bom_07 ON ksx.bom (enterprise_id, bom_id, bom_revision_number);
CREATE INDEX IF NOT EXISTS ix_product_release_request_09 ON ksx.product_release_request (enterprise_id, product_release_request_id);
