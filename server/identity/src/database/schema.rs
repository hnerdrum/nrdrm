// @generated automatically by Diesel CLI.

pub mod sql_types {
    #[derive(diesel::query_builder::QueryId, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "token_status"))]
    pub struct TokenStatus;
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::TokenStatus;

    auth_token (id) {
        id -> Uuid,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
        value -> Text,
        status -> TokenStatus,
        user_id -> Nullable<Uuid>,
    }
}

diesel::table! {
    user_account (id) {
        id -> Uuid,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
        email -> Text,
        password_hash -> Text,
    }
}

diesel::joinable!(auth_token -> user_account (user_id));

diesel::allow_tables_to_appear_in_same_query!(
    auth_token,
    user_account,
);
