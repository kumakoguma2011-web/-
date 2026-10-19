-- Replace :'email' with the deleted account email and :'user_id' with its UUID.
-- Returns all remaining live rows directly tied to the deleted account.
SELECT
  (SELECT count(*) FROM users WHERE email = :'email') AS users,
  (SELECT count(*) FROM profiles p JOIN users u ON u.id = p.user_id WHERE u.email = :'email') AS profiles,
  (SELECT count(*) FROM anon_rules a JOIN users u ON u.id = a.user_id WHERE u.email = :'email') AS anon_rules,
  (SELECT count(*) FROM conversations c JOIN users u ON u.id = c.user_id WHERE u.email = :'email') AS conversations,
  (SELECT count(*) FROM messages m JOIN conversations c ON c.id = m.conversation_id JOIN users u ON u.id = c.user_id WHERE u.email = :'email') AS messages;

-- Use the UUID captured before deleting the users row, since it no longer joins to users.
SELECT count(*) AS chat_requests FROM chat_requests WHERE user_id = :'user_id';

-- Orphan checks: all must be zero.
SELECT count(*) AS orphan_profiles FROM profiles p LEFT JOIN users u ON u.id=p.user_id WHERE u.id IS NULL;
SELECT count(*) AS orphan_anon_rules FROM anon_rules a LEFT JOIN users u ON u.id=a.user_id WHERE u.id IS NULL;
SELECT count(*) AS orphan_conversations FROM conversations c LEFT JOIN users u ON u.id=c.user_id WHERE u.id IS NULL;
SELECT count(*) AS orphan_messages FROM messages m LEFT JOIN conversations c ON c.id=m.conversation_id WHERE c.id IS NULL;
SELECT count(*) AS orphan_chat_requests FROM chat_requests r LEFT JOIN users u ON u.id=r.user_id WHERE u.id IS NULL;
SELECT count(*) AS orphan_conversation_requests FROM chat_requests r LEFT JOIN conversations c ON c.id=r.conversation_id WHERE r.conversation_id IS NOT NULL AND c.id IS NULL;
