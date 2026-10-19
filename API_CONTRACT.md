# ミチシルベ API contract

- POST `/auth/register` `{email,password}` → `{access_token,expires_in}`
- POST `/auth/login` `{email,password}` → `{access_token,expires_in}`
- GET `/profile` → Profile object
- PUT `/profile` → Profile object
- GET `/anon-rules` → AnonRule[]
- POST `/anon-rules` `{original,label}` → AnonRule
- DELETE `/anon-rules/{id}`
- GET `/conversations/latest` → `{conversation_id}`
- GET `/conversations/{id}/messages` → Message[] (owner-only)
- POST `/chat` `{conversation_id?,message,zero_context,step,tone}` → `{conversation_id,answer,step,profile_updates[]}`
- POST `/interview` `{answer}` → `{answer}`
- POST `/survey/analyze` `{q1,q2}` → `{text}`
- GET `/account/export` → user profile/rules/conversations/messages export
- DELETE `/account/data`

The mobile app never sends a Gemini API key. The backend owns the Gemini connection and applies anonymization before AI transmission.
