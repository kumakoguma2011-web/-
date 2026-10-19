CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE users (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email text NOT NULL UNIQUE, password_hash text NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE profiles (user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, data jsonb NOT NULL, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE anon_rules (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, original_text text NOT NULL, replacement_text text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(user_id, original_text));
CREATE TABLE conversations (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, title text NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE messages (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, role text NOT NULL CHECK(role IN ('user','assistant')), content text NOT NULL, step smallint NOT NULL CHECK(step BETWEEN 1 AND 5), created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX conversations_user_idx ON conversations(user_id);
CREATE INDEX messages_conversation_idx ON messages(conversation_id, created_at);
