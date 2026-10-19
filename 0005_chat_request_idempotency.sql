CREATE TABLE IF NOT EXISTS chat_requests (
  client_message_id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  conversation_id uuid REFERENCES conversations(id) ON DELETE SET NULL,
  status text NOT NULL CHECK (status IN ('processing','completed')),
  answer text,
  step smallint,
  profile_updates jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);
CREATE INDEX IF NOT EXISTS chat_requests_user_idx ON chat_requests(user_id, created_at DESC);
