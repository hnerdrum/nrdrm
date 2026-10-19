// @generated automatically by Diesel CLI.

pub mod sql_types {
    #[derive(diesel::query_builder::QueryId, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "token_status"))]
    pub struct TokenStatus;
}

diesel::table! {
    access_token (id) {
        id -> Uuid,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
        token_hash -> Text,
        client_id -> Uuid,
        audience -> Text,
        expires_at -> Timestamptz,
        revoked_at -> Nullable<Timestamptz>,
        user_id -> Nullable<Uuid>,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::TokenStatus;

    auth_token (id) {
        id -> Uuid,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
        status -> TokenStatus,
        user_id -> Uuid,
        issued_at -> Timestamptz,
        expires_at -> Timestamptz,
    }
}

diesel::table! {
    oauth_client (id) {
        id -> Uuid,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
        name -> Text,
        secret_hash -> Text,
    }
}

diesel::table! {
    oauth_client_audience (client_id, audience) {
        client_id -> Uuid,
        audience -> Text,
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

diesel::joinable!(access_token -> oauth_client (client_id));
diesel::joinable!(access_token -> user_account (user_id));
diesel::joinable!(auth_token -> user_account (user_id));
diesel::joinable!(oauth_client_audience -> oauth_client (client_id));

diesel::allow_tables_to_appear_in_same_query!(
    access_token,
    auth_token,
    oauth_client,
    oauth_client_audience,
    user_account,
);
