ALTER TABLE children ADD COLUMN IF NOT EXISTS daily_status TEXT DEFAULT '';
ALTER TABLE children ADD COLUMN IF NOT EXISTS birth_date DATE;

ALTER TABLE progress_reports ADD COLUMN IF NOT EXISTS title VARCHAR(150) DEFAULT '';
ALTER TABLE progress_reports ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'Kegiatan';
ALTER TABLE progress_reports ADD COLUMN IF NOT EXISTS author_name VARCHAR(100) DEFAULT 'Pengurus Panti';

ALTER TABLE letters ADD COLUMN IF NOT EXISTS sender_role VARCHAR(20) DEFAULT 'donor';
ALTER TABLE letters ADD COLUMN IF NOT EXISTS msg_type VARCHAR(20) DEFAULT 'text';
ALTER TABLE letters ADD COLUMN IF NOT EXISTS file_url TEXT DEFAULT '';
ALTER TABLE letters ADD COLUMN IF NOT EXISTS is_gallery_item BOOLEAN DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS child_wishlists (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  child_id          UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
  item_name         VARCHAR(150) NOT NULL,
  estimated_idr     BIGINT NOT NULL DEFAULT 0,
  status            VARCHAR(20) NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open', 'funded', 'fulfilled')),
  funded_by_user_id UUID REFERENCES users(id),
  funded_by_name    VARCHAR(100),
  receipt_url       TEXT DEFAULT '',
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_child_wishlists_child ON child_wishlists(child_id);

ALTER TABLE call_schedules ADD COLUMN IF NOT EXISTS admin_notes TEXT DEFAULT '';
ALTER TABLE call_schedules DROP CONSTRAINT IF EXISTS call_schedules_status_check;
ALTER TABLE call_schedules
  ADD CONSTRAINT call_schedules_status_check
  CHECK (status IN ('scheduled', 'approved', 'rescheduled', 'completed', 'cancelled'));
