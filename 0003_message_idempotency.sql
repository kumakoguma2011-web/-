ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_message_id uuid;
CREATE UNIQUE INDEX IF NOT EXISTS messages_conversation_client_idx
  ON messages(conversation_id, client_message_id)
  WHERE client_message_id IS NOT NULL;
