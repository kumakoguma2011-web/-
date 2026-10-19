DROP INDEX IF EXISTS messages_conversation_client_idx;
CREATE UNIQUE INDEX IF NOT EXISTS messages_client_message_unique_idx
  ON messages(client_message_id)
  WHERE client_message_id IS NOT NULL;
