// @generated automatically by Diesel CLI.

pub mod sql_types {
    #[derive(diesel::query_builder::QueryId, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "activity_provider"))]
    pub struct ActivityProvider;
}

diesel::table! {
    training_session (id) {
        id -> Uuid,
        on_date -> Date,
        body -> Jsonb,
        deleted_at -> Nullable<Timestamptz>,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::ActivityProvider;

    training_session_source (session_id) {
        session_id -> Uuid,
        provider -> ActivityProvider,
        activity_id -> Text,
    }
}

diesel::joinable!(training_session_source -> training_session (session_id));

diesel::allow_tables_to_appear_in_same_query!(training_session, training_session_source,);
