-- Chat idempotency records include AI answers and profile suggestions.
-- If a conversation was deleted before this migration, ON DELETE SET NULL
-- may have left completed records with no owning conversation. Those records
-- cannot be replayed safely, so remove them as part of the migration.
DELETE FROM chat_requests
WHERE status = 'completed'
  AND conversation_id IS NULL;

-- Conversation deletion must also delete cached AI responses used for
-- idempotent retries; retaining them would violate the conversation delete UI.
ALTER TABLE chat_requests
  DROP CONSTRAINT IF EXISTS chat_requests_conversation_id_fkey;

ALTER TABLE chat_requests
  ADD CONSTRAINT chat_requests_conversation_id_fkey
  FOREIGN KEY (conversation_id)
  REFERENCES conversations(id)
  ON DELETE CASCADE;
