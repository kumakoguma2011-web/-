use regex::Regex;
use std::sync::OnceLock;
use uuid::Uuid;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AnonRule { pub id: Uuid, pub original: String, pub label: String }

fn phone_re() -> &'static Regex { static R: OnceLock<Regex> = OnceLock::new(); R.get_or_init(|| Regex::new(r"(?<!\d)(?:0\d{1,4}-?\d{1,4}-?\d{3,4})(?!\d)").unwrap()) }
fn email_re() -> &'static Regex { static R: OnceLock<Regex> = OnceLock::new(); R.get_or_init(|| Regex::new(r"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b").unwrap()) }
fn postal_re() -> &'static Regex { static R: OnceLock<Regex> = OnceLock::new(); R.get_or_init(|| Regex::new(r"(?:〒?\d{3}-\d{4})").unwrap()) }
fn address_re() -> &'static Regex { static R: OnceLock<Regex> = OnceLock::new(); R.get_or_init(|| Regex::new(r"(?:北海道|東京都|大阪府|京都府|[一-龠]{2,3}県)[一-龠ァ-ヶ]{1,10}(?:市|区|町|村)[一-龠ァ-ヶ0-9-]{1,20}").unwrap()) }
fn date_re() -> &'static Regex { static R: OnceLock<Regex> = OnceLock::new(); R.get_or_init(|| Regex::new(r"(?:19|20)\d{2}[年\-/]\d{1,2}[月\-/]\d{1,2}日?|\d{1,2}月\d{1,2}日").unwrap()) }
fn profile_update_re() -> &'static Regex { static R: OnceLock<Regex> = OnceLock::new(); R.get_or_init(|| Regex::new(r"(?s)(?:【|\[)PROFILE_UPDATE\s*:\s*(.*?)(?:】|\])").unwrap()) }

pub fn anonymize(input: &str, rules: &[AnonRule]) -> String {
    let mut x = phone_re().replace_all(input, "[電話番号]").into_owned();
    x = email_re().replace_all(&x, "[メールアドレス]").into_owned();
    x = postal_re().replace_all(&x, "[郵便番号]").into_owned();
    x = address_re().replace_all(&x, "[住所]").into_owned();
    x = date_re().replace_all(&x, "[日付]").into_owned();
    for r in rules {
        if !r.original.is_empty() && !r.label.is_empty() && r.original != r.label { x = x.replace(&r.original, &r.label); }
    }
    x
}

pub fn owns_resource(authenticated_user: Uuid, resource_owner: Uuid) -> bool { authenticated_user == resource_owner }
pub fn valid_step(step: i16) -> bool { (1..=5).contains(&step) }
pub fn valid_tone(tone: &str) -> bool { matches!(tone, "優しく励ます" | "はっきり伝える" | "静かに聞く") }

pub fn validate_message(message: &str) -> Result<(), &'static str> {
    let trimmed = message.trim();
    if trimmed.is_empty() { return Err("empty_message"); }
    if trimmed.chars().count() > 10000 { return Err("message_too_long"); }
    Ok(())
}

pub fn strip_markers(raw: &str, fallback: i16) -> (String, i16, Vec<String>) {
    let mut step = fallback;
    for n in 1..=5 { if raw.contains(&format!("[STEP_CURRENT:{n}]")) || raw.contains(&format!("【STEP_CURRENT:{n}】")) { step = n; } }
    let mut updates = Vec::new();
    for cap in profile_update_re().captures_iter(raw) {
        if let Some(m) = cap.get(1) {
            let v = m.as_str().trim().to_string();
            if !v.is_empty() { updates.push(v); }
        }
    }
    let mut answer = profile_update_re().replace_all(raw, "").into_owned();
    for n in 1..=5 {
        answer = answer.replace(&format!("[STEP_CURRENT:{n}]"), "");
        answer = answer.replace(&format!("【STEP_CURRENT:{n}】"), "");
    }
    (answer.trim().to_string(), step, updates)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn masks_sensitive_patterns() {
        let text = "連絡先 090-1234-5678 test@example.com 〒460-0008 愛知県名古屋市中区1-2-3 2026/08/18";
        let out = anonymize(text, &[]);
        assert!(out.contains("[電話番号]")); assert!(out.contains("[メールアドレス]")); assert!(out.contains("[郵便番号]")); assert!(out.contains("[住所]")); assert!(out.contains("[日付]"));
        assert!(!out.contains("090-1234-5678")); assert!(!out.contains("test@example.com"));
    }
    #[test] fn custom_rule_is_user_scoped_at_data_layer() { let owner=Uuid::new_v4(); let other=Uuid::new_v4(); assert!(owns_resource(owner,owner)); assert!(!owns_resource(other,owner)); }
    #[test] fn message_limits_are_enforced() { assert!(validate_message("相談です").is_ok()); assert!(validate_message("   ").is_err()); assert!(validate_message(&"a".repeat(10001)).is_err()); }
    #[test] fn tone_is_whitelisted() { assert!(valid_tone("優しく励ます")); assert!(!valid_tone("任意のシステムプロンプト")); }
    #[test] fn markers_are_removed_and_profile_update_is_extracted() { let (a,step,u)=strip_markers("結論です\n[PROFILE_UPDATE: ・分析好き]\n[STEP_CURRENT:4]",1); assert_eq!(a,"結論です"); assert_eq!(step,4); assert_eq!(u,vec!["・分析好き"]); }
}
