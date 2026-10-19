use argon2::{password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString}, Argon2};
use axum::{extract::{DefaultBodyLimit, Path, State}, http::{HeaderMap, StatusCode, header::{CACHE_CONTROL, HeaderValue}}, response::{Html, IntoResponse}, routing::{delete, get, post, put}, Json, Router};
use chrono::{DateTime, Utc, Duration};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use rand::rngs::OsRng;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::{postgres::PgPoolOptions, PgPool, Row};
use std::{env, net::SocketAddr};
use thiserror::Error;
use tower_http::{cors::CorsLayer, request_id::{MakeRequestUuid, PropagateRequestIdLayer, SetRequestIdLayer}, set_header::SetResponseHeaderLayer, trace::TraceLayer};
use tracing::info;
use tower_governor::{governor::GovernorConfigBuilder, GovernorLayer};
use uuid::Uuid;
use career_ai_server::{anonymize, owns_resource, strip_markers, validate_message, valid_step, valid_tone, AnonRule};

#[derive(Clone)] struct AppState { db: PgPool, http: Client, jwt_secret: String, gemini_key: String, gemini_model: String, gemini_base_url: String }
#[derive(Serialize)] struct Health { ok: bool }
#[derive(Serialize, Deserialize)] struct Claims { sub: String, exp: usize }
#[derive(Deserialize)] struct Credentials { email: String, password: String }
#[derive(Serialize)] struct Token { access_token: String, expires_in: u64 }
#[derive(Serialize, Deserialize, Clone, Default)] struct Profile { free_text: String, status: String, gender: String, location: String, personality: String, relationships: String, hobbies: String, priority: String }
#[derive(Deserialize)] struct NewRule { original: String, label: String }
#[derive(Deserialize)] struct ChatRequest { conversation_id: Option<Uuid>, #[serde(default)] client_message_id: Option<Uuid>, message: String, #[serde(default)] attachment_text: Option<String>, #[serde(default)] attachment_name: Option<String>, zero_context: bool, step: i16, #[serde(default = "default_tone")] tone: String }
#[derive(Serialize)] struct ChatResponse { conversation_id: Uuid, answer: String, step: i16, profile_updates: Vec<String> }
#[derive(Deserialize)] struct InterviewRequest { answer: String }
#[derive(Serialize)] struct InterviewResponse { answer: String }
#[derive(Deserialize)] struct SurveyRequest { q1: String, q2: String }
#[derive(Serialize)] struct TextResponse { text: String }
#[derive(Serialize)] struct PromptPreview { prompt: String, profile_included: bool, anonymization_applied: bool, attachment_included: bool }
#[derive(Serialize)] struct MessageOut { role: String, content: String, step: i16, created_at: DateTime<Utc> }
#[derive(Serialize)] struct ConversationRef { conversation_id: Option<Uuid> }
#[derive(Debug, Error)] enum AppError { #[error("bad request: {0}")] BadRequest(String), #[error("unauthorized")] Unauthorized, #[error("conflict: {0}")] Conflict(String), #[error("not found")] NotFound, #[error("internal")] Internal }
type Result<T> = std::result::Result<T, AppError>;
fn default_tone() -> String { "優しく励ます".into() }
impl IntoResponse for AppError { fn into_response(self)->axum::response::Response { let (s,m)=match self {AppError::BadRequest(m)=>(StatusCode::BAD_REQUEST,m),AppError::Unauthorized=>(StatusCode::UNAUTHORIZED,"認証が必要です".into()),AppError::Conflict(m)=>(StatusCode::CONFLICT,m),AppError::NotFound=>(StatusCode::NOT_FOUND,"見つかりません".into()),AppError::Internal=>(StatusCode::INTERNAL_SERVER_ERROR,"サーバーエラーが発生しました".into())}; (s,Json(json!({"message":m}))).into_response() } }
fn hash_password(p:&str)->Result<String>{let salt=SaltString::generate(&mut OsRng);Argon2::default().hash_password(p.as_bytes(),&salt).map(|x|x.to_string()).map_err(|_|AppError::Internal)}
fn verify_password(p:&str,h:&str)->bool{PasswordHash::new(h).ok().map(|x|Argon2::default().verify_password(p.as_bytes(),&x).is_ok()).unwrap_or(false)}
fn issue_token(s:&AppState,id:Uuid)->Result<Token>{let secs=8*60*60u64;let exp=(Utc::now()+Duration::seconds(secs as i64)).timestamp() as usize;let t=encode(&Header::default(),&Claims{sub:id.to_string(),exp},&EncodingKey::from_secret(s.jwt_secret.as_bytes())).map_err(|_|AppError::Internal)?;Ok(Token{access_token:t,expires_in:secs})}
async fn auth(headers:&HeaderMap,s:&AppState)->Result<Uuid>{let raw=headers.get("authorization").and_then(|v|v.to_str().ok()).ok_or(AppError::Unauthorized)?;let t=raw.strip_prefix("Bearer ").ok_or(AppError::Unauthorized)?;let c=decode::<Claims>(t,&DecodingKey::from_secret(s.jwt_secret.as_bytes()),&Validation::default()).map_err(|_|AppError::Unauthorized)?;let uid=Uuid::parse_str(&c.claims.sub).map_err(|_|AppError::Unauthorized)?;let exists=sqlx::query_scalar::<_,Uuid>("SELECT id FROM users WHERE id=$1").bind(uid).fetch_optional(&s.db).await.map_err(|_|AppError::Internal)?;if exists.is_none(){return Err(AppError::Unauthorized)}Ok(uid)}
fn valid_email(e:&str)->bool{e.len()<=254&&e.contains('@')&&!e.chars().any(|c|matches!(c,' '|'\n'|'\r'))}
async fn health()->Json<Health>{Json(Health{ok:true})}
async fn register(State(s):State<AppState>,Json(c):Json<Credentials>)->Result<(StatusCode,Json<Token>)>{let email=c.email.trim().to_lowercase();if !valid_email(&email)||c.password.len()<12{return Err(AppError::BadRequest("有効なメールアドレスと12文字以上のパスワードが必要です".into()))}let h=hash_password(&c.password)?;let id=sqlx::query_scalar::<_,Uuid>("INSERT INTO users(email,password_hash) VALUES($1,$2) RETURNING id").bind(email).bind(h).fetch_one(&s.db).await.map_err(|e|if e.to_string().contains("duplicate"){AppError::Conflict("登録できませんでした。入力内容を確認してください。".into())}else{AppError::Internal})?;Ok((StatusCode::CREATED,Json(issue_token(&s,id)?)))}
async fn login(State(s):State<AppState>,Json(c):Json<Credentials>)->Result<Json<Token>>{let email=c.email.trim().to_lowercase();let row=sqlx::query("SELECT id,password_hash FROM users WHERE email=$1").bind(email).fetch_optional(&s.db).await.map_err(|_|AppError::Internal)?.ok_or(AppError::Unauthorized)?;let id:Uuid=row.try_get("id").map_err(|_|AppError::Internal)?;let h:String=row.try_get("password_hash").map_err(|_|AppError::Internal)?;if !verify_password(&c.password,&h){return Err(AppError::Unauthorized)}Ok(Json(issue_token(&s,id)?))}
async fn profile_get(State(s):State<AppState>,h:HeaderMap)->Result<Json<Profile>>{let uid=auth(&h,&s).await?;let row=sqlx::query("SELECT data FROM profiles WHERE user_id=$1").bind(uid).fetch_optional(&s.db).await.map_err(|_|AppError::Internal)?;Ok(Json(row.and_then(|r|r.try_get::<Value,_>("data").ok()).and_then(|v|serde_json::from_value(v).ok()).unwrap_or_default()))}
async fn profile_put(State(s):State<AppState>,h:HeaderMap,Json(p):Json<Profile>)->Result<Json<Profile>>{let uid=auth(&h,&s).await?;if p.free_text.chars().count()>10000||p.location.chars().count()>200||p.personality.chars().count()>1000||p.relationships.chars().count()>1000||p.hobbies.chars().count()>1000||p.status.chars().count()>200||p.gender.chars().count()>100||p.priority.chars().count()>200{return Err(AppError::BadRequest("プロフィールが大きすぎます".into()))}let v=serde_json::to_value(&p).map_err(|_|AppError::BadRequest("不正なプロフィールです".into()))?;sqlx::query("INSERT INTO profiles(user_id,data) VALUES($1,$2) ON CONFLICT(user_id) DO UPDATE SET data=EXCLUDED.data,updated_at=now()").bind(uid).bind(v).execute(&s.db).await.map_err(|_|AppError::Internal)?;Ok(Json(p))}
async fn rules_get(State(s):State<AppState>,h:HeaderMap)->Result<Json<Vec<AnonRule>>>{let uid=auth(&h,&s).await?;let rows=sqlx::query("SELECT id,original_text,replacement_text FROM anon_rules WHERE user_id=$1 ORDER BY created_at").bind(uid).fetch_all(&s.db).await.map_err(|_|AppError::Internal)?;Ok(Json(rows.into_iter().map(|r|AnonRule{id:r.try_get("id").unwrap(),original:r.try_get("original_text").unwrap(),label:r.try_get("replacement_text").unwrap()}).collect()))}
async fn rules_post(State(s):State<AppState>,h:HeaderMap,Json(n):Json<NewRule>)->Result<(StatusCode,Json<AnonRule>)>{let uid=auth(&h,&s).await?;if n.original.trim().is_empty()||n.label.trim().is_empty()||n.original.chars().count()>200||n.label.chars().count()>100{return Err(AppError::BadRequest("仮名化ルールが不正です".into()))}let row=sqlx::query("INSERT INTO anon_rules(user_id,original_text,replacement_text) VALUES($1,$2,$3) RETURNING id,original_text,replacement_text").bind(uid).bind(n.original.trim()).bind(n.label.trim()).fetch_one(&s.db).await.map_err(|e|if e.to_string().contains("duplicate"){AppError::Conflict("同じルールが既に存在します".into())}else{AppError::Internal})?;Ok((StatusCode::CREATED,Json(AnonRule{id:row.try_get("id").unwrap(),original:row.try_get("original_text").unwrap(),label:row.try_get("replacement_text").unwrap()})))}
async fn rules_delete(State(s):State<AppState>,h:HeaderMap,Path(id):Path<Uuid>)->Result<StatusCode>{let uid=auth(&h,&s).await?;let n=sqlx::query("DELETE FROM anon_rules WHERE id=$1 AND user_id=$2").bind(id).bind(uid).execute(&s.db).await.map_err(|_|AppError::Internal)?;if n.rows_affected()==0{return Err(AppError::NotFound)}Ok(StatusCode::NO_CONTENT)}
async fn load_rules(db:&PgPool,uid:Uuid)->Result<Vec<AnonRule>>{let rows=sqlx::query("SELECT id,original_text,replacement_text FROM anon_rules WHERE user_id=$1 ORDER BY created_at").bind(uid).fetch_all(db).await.map_err(|_|AppError::Internal)?;Ok(rows.into_iter().map(|r|AnonRule{id:r.try_get("id").unwrap(),original:r.try_get("original_text").unwrap(),label:r.try_get("replacement_text").unwrap()}).collect())}
async fn load_profile(db:&PgPool,uid:Uuid)->Result<Option<Profile>>{let row=sqlx::query("SELECT data FROM profiles WHERE user_id=$1").bind(uid).fetch_optional(db).await.map_err(|_|AppError::Internal)?;Ok(row.and_then(|r|r.try_get::<Value,_>("data").ok()).and_then(|v|serde_json::from_value(v).ok()))}
async fn latest_conversation(State(s):State<AppState>,h:HeaderMap)->Result<Json<ConversationRef>>{let uid=auth(&h,&s).await?;let cid=sqlx::query_scalar::<_,Uuid>("SELECT id FROM conversations WHERE user_id=$1 ORDER BY updated_at DESC, created_at DESC LIMIT 1").bind(uid).fetch_optional(&s.db).await.map_err(|_|AppError::Internal)?;Ok(Json(ConversationRef{conversation_id:cid}))}
async fn messages_get(State(s):State<AppState>,h:HeaderMap,Path(cid):Path<Uuid>)->Result<Json<Vec<MessageOut>>>{let uid=auth(&h,&s).await?;let owner=sqlx::query_scalar::<_,Uuid>("SELECT user_id FROM conversations WHERE id=$1").bind(cid).fetch_optional(&s.db).await.map_err(|_|AppError::Internal)?.ok_or(AppError::NotFound)?;if !owns_resource(uid,owner){return Err(AppError::Unauthorized)}let rows=sqlx::query("SELECT role,content,step,created_at FROM messages WHERE conversation_id=$1 ORDER BY created_at ASC").bind(cid).fetch_all(&s.db).await.map_err(|_|AppError::Internal)?;let out=rows.into_iter().map(|r|MessageOut{role:r.try_get("role").unwrap(),content:r.try_get("content").unwrap(),step:r.try_get("step").unwrap(),created_at:r.try_get("created_at").unwrap()}).collect();Ok(Json(out))}
async fn build_gemini(s:&AppState,prompt:String)->Result<String>{let url=format!("{}/v1beta/models/{}:generateContent",s.gemini_base_url.trim_end_matches('/'),s.gemini_model);let body=json!({"contents":[{"role":"user","parts":[{"text":prompt}]}],"generationConfig":{}});let res=s.http.post(url).header("x-goog-api-key",&s.gemini_key).json(&body).send().await.map_err(|_|AppError::Internal)?;if !res.status().is_success(){return Err(AppError::Internal)}let v:Value=res.json().await.map_err(|_|AppError::Internal)?;v["candidates"][0]["content"]["parts"][0]["text"].as_str().map(|x|x.to_string()).ok_or(AppError::Internal)}
async fn conversations_post(State(s):State<AppState>,h:HeaderMap)->Result<(StatusCode,Json<ConversationRef>)>{let uid=auth(&h,&s).await?;let cid=sqlx::query_scalar::<_,Uuid>("INSERT INTO conversations(user_id,title) VALUES($1,$2) RETURNING id").bind(uid).bind("新しい相談").fetch_one(&s.db).await.map_err(|_|AppError::Internal)?;Ok((StatusCode::CREATED,Json(ConversationRef{conversation_id:Some(cid)})))}
async fn conversation_delete(State(s):State<AppState>,h:HeaderMap,Path(cid):Path<Uuid>)->Result<StatusCode>{
 let uid=auth(&h,&s).await?;
 let owner=sqlx::query_scalar::<_,Uuid>("SELECT user_id FROM conversations WHERE id=$1").bind(cid).fetch_optional(&s.db).await.map_err(|_|AppError::Internal)?.ok_or(AppError::NotFound)?;
 if !owns_resource(uid,owner){return Err(AppError::Unauthorized)}
 sqlx::query("DELETE FROM conversations WHERE id=$1 AND user_id=$2").bind(cid).bind(uid).execute(&s.db).await.map_err(|_|AppError::Internal)?;
 Ok(StatusCode::NO_CONTENT)
}

async fn wait_for_chat_request(s:&AppState,uid:Uuid,mid:Uuid)->Result<Option<(Uuid,String,i16,Vec<String>)>>{
    for _ in 0..60 {
        let row=sqlx::query("SELECT conversation_id,status,answer,step,profile_updates,user_id FROM chat_requests WHERE client_message_id=$1").bind(mid).fetch_optional(&s.db).await.map_err(|_|AppError::Internal)?;
        let Some(row)=row else { return Ok(None); };
        let owner:Uuid=row.try_get("user_id").map_err(|_|AppError::Internal)?;
        if owner!=uid{return Err(AppError::Unauthorized)}
        let status:String=row.try_get("status").map_err(|_|AppError::Internal)?;
        if status=="completed" {
            let cid:Uuid=row.try_get("conversation_id").map_err(|_|AppError::Internal)?;
            let answer:String=row.try_get("answer").map_err(|_|AppError::Internal)?;
            let step:i16=row.try_get("step").map_err(|_|AppError::Internal)?;
            let updates:Vec<String>=row.try_get::<Value,_>("profile_updates").ok().and_then(|v|serde_json::from_value(v).ok()).unwrap_or_default();
            return Ok(Some((cid,answer,step,updates)));
        }
        tokio::time::sleep(std::time::Duration::from_millis(250)).await;
    }
    Err(AppError::Conflict("同じ相談を処理中です。少し待ってからもう一度お試しください。".into()))
}

async fn chat(State(s):State<AppState>,h:HeaderMap,Json(r):Json<ChatRequest>)->Result<Json<ChatResponse>>{
 let uid=auth(&h,&s).await?;
 if r.message.trim().is_empty() && r.attachment_text.as_deref().map(str::trim).filter(|x| !x.is_empty()).is_none(){return Err(AppError::BadRequest("メッセージまたは添付テキストが必要です".into()));}
 if !r.message.trim().is_empty(){validate_message(&r.message).map_err(|e|AppError::BadRequest(e.into()))?;}
 if let Some(a)=&r.attachment_text{if a.as_bytes().len()>262144{return Err(AppError::BadRequest("添付テキストが大きすぎます".into()));}}
 if let Some(n)=&r.attachment_name{if n.chars().count()>200||n.contains('\n')||n.contains('\r'){return Err(AppError::BadRequest("添付ファイル名が不正です".into()));}}
 if !valid_step(r.step)||!valid_tone(&r.tone){return Err(AppError::BadRequest("step または tone が不正です".into()));}
 let existing_cid=if let Some(cid)=r.conversation_id{let owner=sqlx::query_scalar::<_,Uuid>("SELECT user_id FROM conversations WHERE id=$1").bind(cid).fetch_optional(&s.db).await.map_err(|_|AppError::Internal)?.ok_or(AppError::NotFound)?;if !owns_resource(uid,owner){return Err(AppError::Unauthorized)}Some(cid)}else{None};
 let rules=load_rules(&s.db,uid).await?;
 let safe=anonymize(&r.message,&rules);
 let safe_attachment=r.attachment_text.as_deref().map(|x|anonymize(x,&rules));
 let stored=if let Some(text)=safe_attachment.as_deref(){format!("{}\n\n【添付ファイル】\n{}",safe,text)}else{safe.clone()};
 if stored.chars().count()>280000{return Err(AppError::BadRequest("送信内容が大きすぎます".into()));}
 let mut prompt=format!("あなたはミチシルベです。日本語で回答してください。相談者を尊重し、実行可能な提案を行ってください。\n現在ステップ:{}\nトーン:{}\n",r.step,r.tone);
 if !r.zero_context{if let Some(p)=load_profile(&s.db,uid).await?{prompt.push_str("プロフィール（仮名化済み）:\n");prompt.push_str(&anonymize(&serde_json::to_string(&p).unwrap(),&rules));prompt.push('\n')}}else{prompt.push_str("ZERO-CONTEXT: プロフィール情報を利用しない。\n")}
 prompt.push_str("会話の中で恒常的な強み・価値観などの新しい発見があれば、最後に[PROFILE_UPDATE: 箇条書き]を1つだけ付ける。1件あたり500文字以内、最大5件。\n末尾に[STEP_CURRENT:N]を1つ付ける。\nユーザーメッセージ:\n");prompt.push_str(&stored);
 if let Some(mid)=r.client_message_id {
   let inserted=sqlx::query("INSERT INTO chat_requests(client_message_id,user_id,conversation_id,status) VALUES($1,$2,$3,'processing') ON CONFLICT (client_message_id) DO NOTHING")
     .bind(mid).bind(uid).bind(existing_cid).execute(&s.db).await.map_err(|_|AppError::Internal)?;
   if inserted.rows_affected()==0 {
      if let Some((cid,answer,step,updates))=wait_for_chat_request(&s,uid,mid).await? {return Ok(Json(ChatResponse{conversation_id:cid,answer,step,profile_updates:updates}));}
      return Err(AppError::Conflict("同じ相談を処理中です。少し待ってからもう一度お試しください。".into()));
   }
 }
 let raw=match build_gemini(&s,prompt).await { Ok(v)=>v, Err(e)=>{ if let Some(mid)=r.client_message_id{let _=sqlx::query("DELETE FROM chat_requests WHERE client_message_id=$1 AND user_id=$2 AND status='processing'").bind(mid).bind(uid).execute(&s.db).await;} return Err(e); } };
 let (answer,step,updates)=strip_markers(&raw,r.step);
 let persist_result: Result<Uuid> = async {
   let mut tx=s.db.begin().await.map_err(|_|AppError::Internal)?;
   let cid=if let Some(cid)=existing_cid{cid}else{sqlx::query_scalar::<_,Uuid>("INSERT INTO conversations(user_id,title) VALUES($1,$2) RETURNING id").bind(uid).bind("新しい相談").fetch_one(&mut *tx).await.map_err(|_|AppError::Internal)?};
   if let Some(mid)=r.client_message_id{
      let row=sqlx::query("SELECT user_id,status FROM chat_requests WHERE client_message_id=$1 FOR UPDATE").bind(mid).fetch_one(&mut *tx).await.map_err(|_|AppError::Internal)?;
      let owner:Uuid=row.try_get("user_id").map_err(|_|AppError::Internal)?;
      let status:String=row.try_get("status").map_err(|_|AppError::Internal)?;
      if owner!=uid || status!="processing"{tx.rollback().await.map_err(|_|AppError::Internal)?;return Err(AppError::Conflict("この相談はすでに処理されています。".into()));}
      sqlx::query("UPDATE chat_requests SET conversation_id=$2,answer=$3,step=$4,profile_updates=$5,status='completed',completed_at=now() WHERE client_message_id=$1")
        .bind(mid).bind(cid).bind(&answer).bind(step).bind(json!(updates)).execute(&mut *tx).await.map_err(|_|AppError::Internal)?;
   }
   sqlx::query("INSERT INTO messages(conversation_id,role,content,step,client_message_id) VALUES($1,'user',$2,$3,$4)").bind(cid).bind(&stored).bind(r.step).bind(r.client_message_id).execute(&mut *tx).await.map_err(|e|if e.to_string().contains("unique"){AppError::Conflict("同じ相談がすでに処理されています。".into())}else{AppError::Internal})?;
   sqlx::query("INSERT INTO messages(conversation_id,role,content,step) VALUES($1,'assistant',$2,$3)").bind(cid).bind(&answer).bind(step).execute(&mut *tx).await.map_err(|_|AppError::Internal)?;
   sqlx::query("UPDATE conversations SET updated_at=now() WHERE id=$1").bind(cid).execute(&mut *tx).await.map_err(|_|AppError::Internal)?;
   tx.commit().await.map_err(|_|AppError::Internal)?;
   Ok(cid)
 }.await;
 let cid=match persist_result {
   Ok(cid)=>cid,
   Err(e)=>{
     if let Some(mid)=r.client_message_id{let _=sqlx::query("DELETE FROM chat_requests WHERE client_message_id=$1 AND user_id=$2 AND status='processing'").bind(mid).bind(uid).execute(&s.db).await;}
     return Err(e)
   }
 };
 Ok(Json(ChatResponse{conversation_id:cid,answer,step,profile_updates:updates}))
}
async fn chat_preview(State(s):State<AppState>,h:HeaderMap,Json(r):Json<ChatRequest>)->Result<Json<PromptPreview>>{
 let uid=auth(&h,&s).await?;
 if r.message.chars().count()>10000{return Err(AppError::BadRequest("メッセージが長すぎます".into()));}
 if let Some(a)=&r.attachment_text{if a.as_bytes().len()>262144{return Err(AppError::BadRequest("添付テキストが大きすぎます".into()));}}
 if let Some(n)=&r.attachment_name{if n.chars().count()>200||n.contains(['\n','\r']){return Err(AppError::BadRequest("添付ファイル名が不正です".into()));}}
 if !valid_step(r.step)||!valid_tone(&r.tone){return Err(AppError::BadRequest("step または tone が不正です".into()));}
 let rules=load_rules(&s.db,uid).await?;
 let safe=anonymize(&r.message,&rules);
 let safe_attachment=r.attachment_text.as_deref().map(|x|anonymize(x,&rules));
 let stored=if let Some(text)=safe_attachment.as_deref(){format!("{}\n\n【添付ファイル】\n{}",safe,text)}else{safe.clone()};
 let mut prompt=format!("あなたはミチシルベです。日本語で回答してください。相談者を尊重し、実行可能な提案を行ってください。\n現在ステップ:{}\nトーン:{}\n",r.step,r.tone);
 let profile_included=!r.zero_context;
 if profile_included {if let Some(p)=load_profile(&s.db,uid).await?{prompt.push_str("プロフィール（仮名化済み）:\n");prompt.push_str(&anonymize(&serde_json::to_string(&p).unwrap(),&rules));prompt.push('\n');}}
 else {prompt.push_str("ZERO-CONTEXT: プロフィール情報を利用しない。\n");}
 prompt.push_str("会話の中で恒常的な強み・価値観などの新しい発見があれば、最後に[PROFILE_UPDATE: 箇条書き]を1つだけ付ける。1件あたり500文字以内、最大5件。\n末尾に[STEP_CURRENT:N]を1つ付ける。\nユーザーメッセージ:\n");prompt.push_str(&stored);
 Ok(Json(PromptPreview{prompt,profile_included,anonymization_applied:true,attachment_included:r.attachment_text.as_ref().map(|x|!x.is_empty()).unwrap_or(false)}))
}
async fn interview(State(s):State<AppState>,h:HeaderMap,Json(r):Json<InterviewRequest>)->Result<Json<InterviewResponse>>{let uid=auth(&h,&s).await?;let rules=load_rules(&s.db,uid).await?;if r.answer.trim().is_empty()||r.answer.chars().count()>10000{return Err(AppError::BadRequest("回答が不正です".into()))}let safe=anonymize(&r.answer,&rules);let prompt=format!("以下の面接回答をSTAR法（Situation, Task, Action, Result）で評価し、改善点を日本語で具体的に説明してください。プロフィールや過去の会話は利用しません。\n\n回答:\n{}",safe);let ans=build_gemini(&s,prompt).await?;Ok(Json(InterviewResponse{answer:ans} ))}
async fn survey_analyze(State(s):State<AppState>,h:HeaderMap,Json(r):Json<SurveyRequest>)->Result<Json<TextResponse>>{let uid=auth(&h,&s).await?;if r.q1.chars().count()>500||r.q2.chars().count()>500{return Err(AppError::BadRequest("診断回答が大きすぎます".into()))}let rules=load_rules(&s.db,uid).await?;let q1=anonymize(&r.q1,&rules);let q2=anonymize(&r.q2,&rules);let prompt=format!("次の2つの適性診断回答から、相談者の傾向を短く日本語で分析してください。断定ではなく仮説として述べてください。\nQ1:{}\nQ2:{}",q1,q2);let text=build_gemini(&s,prompt).await?;Ok(Json(TextResponse{text}))}
async fn export_account(State(s):State<AppState>,h:HeaderMap)->Result<Json<Value>>{let uid=auth(&h,&s).await?;let profile=load_profile(&s.db,uid).await?;let rules=load_rules(&s.db,uid).await?;let convs=sqlx::query("SELECT id,title,created_at FROM conversations WHERE user_id=$1 ORDER BY created_at").bind(uid).fetch_all(&s.db).await.map_err(|_|AppError::Internal)?;let mut conversations=Vec::new();for c in convs{let cid:Uuid=c.try_get("id").unwrap();let rows=sqlx::query("SELECT role,content,step,created_at FROM messages WHERE conversation_id=$1 ORDER BY created_at").bind(cid).fetch_all(&s.db).await.map_err(|_|AppError::Internal)?;let messages:Vec<Value>=rows.into_iter().map(|r|json!({"role":r.try_get::<String,_>("role").unwrap(),"content":r.try_get::<String,_>("content").unwrap(),"step":r.try_get::<i16,_>("step").unwrap(),"created_at":r.try_get::<DateTime<Utc>,_>("created_at").unwrap()})).collect();conversations.push(json!({"id":cid,"title":c.try_get::<String,_>("title").unwrap(),"created_at":c.try_get::<DateTime<Utc>,_>("created_at").unwrap(),"messages":messages}));}Ok(Json(json!({"exported_at":Utc::now(),"profile":profile,"anon_rules":rules,"conversations":conversations})))}
async fn account_delete(State(s):State<AppState>,h:HeaderMap)->Result<StatusCode>{let uid=auth(&h,&s).await?;let mut tx=s.db.begin().await.map_err(|_|AppError::Internal)?;sqlx::query("DELETE FROM messages WHERE conversation_id IN (SELECT id FROM conversations WHERE user_id=$1)").bind(uid).execute(&mut *tx).await.map_err(|_|AppError::Internal)?;sqlx::query("DELETE FROM conversations WHERE user_id=$1").bind(uid).execute(&mut *tx).await.map_err(|_|AppError::Internal)?;sqlx::query("DELETE FROM anon_rules WHERE user_id=$1").bind(uid).execute(&mut *tx).await.map_err(|_|AppError::Internal)?;sqlx::query("DELETE FROM profiles WHERE user_id=$1").bind(uid).execute(&mut *tx).await.map_err(|_|AppError::Internal)?;sqlx::query("DELETE FROM users WHERE id=$1").bind(uid).execute(&mut *tx).await.map_err(|_|AppError::Internal)?;tx.commit().await.map_err(|_|AppError::Internal)?;Ok(StatusCode::NO_CONTENT)}
async fn account_deletion_page()->Html<&'static str>{Html(include_str!("static/account_deletion.html"))}
#[tokio::main] async fn main()->Result<()>{dotenvy::dotenv().ok();tracing_subscriber::fmt().json().init();let jwt_secret=env::var("JWT_SECRET").map_err(|_|AppError::Internal)?;if jwt_secret.len()<32{return Err(AppError::Internal)}let gemini_key=env::var("GEMINI_API_KEY").map_err(|_|AppError::Internal)?;let db=PgPoolOptions::new().max_connections(10).connect(&env::var("DATABASE_URL").map_err(|_|AppError::Internal)?).await.map_err(|_|AppError::Internal)?;sqlx::migrate!().run(&db).await.map_err(|_|AppError::Internal)?;let http=Client::builder().timeout(std::time::Duration::from_secs(35)).build().map_err(|_|AppError::Internal)?;let s=AppState{db,http,jwt_secret,gemini_key,gemini_model:env::var("GEMINI_MODEL").unwrap_or("gemini-3.6-flash".into()),gemini_base_url:env::var("GEMINI_BASE_URL").unwrap_or("https://generativelanguage.googleapis.com".into())};let governor_conf=GovernorConfigBuilder::default().per_second(2).burst_size(20).use_headers().finish().map_err(|_|AppError::Internal)?;let app=Router::new().route("/health",get(health)).route("/account-deletion",get(account_deletion_page)).route("/auth/register",post(register)).route("/auth/login",post(login)).route("/profile",get(profile_get).put(profile_put)).route("/anon-rules",get(rules_get).post(rules_post)).route("/anon-rules/{id}",delete(rules_delete)).route("/conversations",post(conversations_post)).route("/conversations/latest",get(latest_conversation)).route("/conversations/{id}/messages",get(messages_get))
.route("/conversations/{id}",delete(conversation_delete)).route("/chat",post(chat)) .route("/chat/preview",post(chat_preview)).route("/interview",post(interview)).route("/survey/analyze",post(survey_analyze)).route("/account/export",get(export_account)).route("/account/data",delete(account_delete)).layer(GovernorLayer::new(governor_conf)).layer(SetRequestIdLayer::x_request_id(MakeRequestUuid)).layer(PropagateRequestIdLayer::x_request_id()).layer(TraceLayer::new_for_http()).layer(CorsLayer::very_strict()).layer(SetResponseHeaderLayer::if_not_present(CACHE_CONTROL,HeaderValue::from_static("no-store"))).layer(DefaultBodyLimit::max(450_000)).with_state(s);let addr:SocketAddr=env::var("BIND_ADDR").unwrap_or("127.0.0.1:8080".into()).parse().map_err(|_|AppError::Internal)?;let listener=tokio::net::TcpListener::bind(addr).await.map_err(|_|AppError::Internal)?;info!(%addr,"ミチシルベ server started");axum::serve(listener,app.into_make_service_with_connect_info::<SocketAddr>()).await.map_err(|_|AppError::Internal)?;Ok(())}
