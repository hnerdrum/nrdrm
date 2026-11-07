// @generated automatically by Diesel CLI.

diesel::table! {
    session (id) {
        id -> Uuid,
        on_date -> Date,
        body -> Jsonb,
    }
}
