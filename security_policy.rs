use career_ai_server::{anonymize, owns_resource, validate_message, AnonRule};
use uuid::Uuid;

#[test]
fn cross_user_resource_access_is_rejected_by_owner_check() {
    let alice = Uuid::new_v4();
    let bob = Uuid::new_v4();
    assert!(owns_resource(alice, alice));
    assert!(!owns_resource(alice, bob));
}

#[test]
fn user_custom_anonymization_is_applied() {
    let rule = AnonRule { id: Uuid::new_v4(), original: "株式会社サンプル".into(), label: "[会社A]".into() };
    let result = anonymize("株式会社サンプルで働いています", &[rule]);
    assert_eq!(result, "[会社A]で働いています");
}

#[test]
fn automatic_pii_patterns_are_removed_before_ai() {
    let result = anonymize("090-1234-5678 / a@example.com / 〒460-0008 / 2026/08/18", &[]);
    assert!(!result.contains("090-1234-5678"));
    assert!(!result.contains("a@example.com"));
    assert!(!result.contains("460-0008"));
    assert!(!result.contains("2026/08/18"));
}

#[test]
fn message_size_limit_is_enforced() {
    assert!(validate_message("相談です").is_ok());
    assert!(validate_message(" ").is_err());
    assert!(validate_message(&"x".repeat(10001)).is_err());
}
