// @generated automatically by Diesel CLI.

diesel::table! {
    user_account (id) {
        id -> Uuid,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
        email -> Text,
        password_hash -> Text,
    }
}
