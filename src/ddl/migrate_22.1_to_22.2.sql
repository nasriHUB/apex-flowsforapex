
-- Add Assignment Data Changes to Flow Subflows and check it is JSON

ALTER TABLE flow_subflows
    ADD ( sbfl_task_ownership varchar2(4000));

ALTER TABLE flow_subflows
    ADD CONSTRAINT sbfl_task_ownership_json CHECK ( sbfl_task_ownership IS JSON );