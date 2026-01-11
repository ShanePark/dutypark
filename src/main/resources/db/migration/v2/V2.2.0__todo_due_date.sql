ALTER TABLE todo ADD COLUMN due_date DATE NULL AFTER completed_date;
CREATE INDEX idx_todo_due_date ON todo(due_date);
CREATE INDEX idx_todo_member_due_date ON todo(member_id, due_date);
