//! The `session_blocks` migration, run against temporary tables that shadow
//! `training_session` and `training_preset` for this connection only.

use diesel::connection::SimpleConnection;
use diesel::prelude::*;
use diesel::sql_types::Text;
use serde_json::{json, Value};

use crate::domain::session::SessionBody;

const URL: &str = "postgres://nrdrm:nrdrm@localhost:5437/training";
const UP: &str = include_str!("../../migrations/2026-11-17-180000_session_blocks/up.sql");
const DOWN: &str = include_str!("../../migrations/2026-11-17-180000_session_blocks/down.sql");

#[derive(QueryableByName)]
struct Row {
    #[diesel(sql_type = Text)]
    body: String,
}

fn shadow(rows: &[Value]) -> PgConnection {
    let mut conn = PgConnection::establish(URL).expect("connection");
    conn.batch_execute(
        r#"CREATE TEMP TABLE "training_session" ("n" SERIAL, "body" JSONB NOT NULL);
           CREATE TEMP TABLE "training_preset" ("n" SERIAL, "body" JSONB NOT NULL);"#,
    )
    .expect("temp tables");
    for table in ["training_session", "training_preset"] {
        for row in rows {
            diesel::sql_query(format!(
                r#"INSERT INTO "{table}" ("body") VALUES ($1::jsonb)"#
            ))
            .bind::<Text, _>(row.to_string())
            .execute(&mut conn)
            .expect("insert");
        }
    }
    conn
}

fn bodies(conn: &mut PgConnection, table: &str) -> Vec<Value> {
    diesel::sql_query(format!(
        r#"SELECT "body"::text AS body FROM "{table}" ORDER BY "n""#
    ))
    .load::<Row>(conn)
    .expect("select")
    .into_iter()
    .map(|row| serde_json::from_str(&row.body).unwrap())
    .collect()
}

fn old_bodies() -> Vec<Value> {
    vec![
        json!({ "sport": "run", "distance": 5000, "duration": 1500 }),
        json!({ "sport": "ride", "distance": 5600, "duration": 1650, "intervals": [
            { "repetitions": 4, "distance": 1000, "duration": 220, "recovery": 90 },
            { "repetitions": 4, "distance": 400, "duration": 80, "recovery": 60 },
        ]}),
        json!({ "sport": "ski", "distance": 12000, "duration": 3600, "intervals": [] }),
        json!({ "sport": "strength", "exercises": [
            { "name": "squat", "sets": [{ "reps": 5, "weight": 100 }] },
            { "name": "plank", "sets": [{ "duration": 45 }] },
        ]}),
        json!({ "sport": "strength", "exercises": [] }),
    ]
}

fn new_bodies() -> Vec<Value> {
    vec![
        json!({ "sport": "run", "distance": 5000, "duration": 1500 }),
        json!({ "sport": "ride", "distance": 5600, "duration": 1650, "blocks": [
            { "kind": "repeats", "repetitions": 4, "distance": 1000, "duration": 220, "recovery": 90 },
            { "kind": "repeats", "repetitions": 4, "distance": 400, "duration": 80, "recovery": 60 },
        ]}),
        json!({ "sport": "ski", "distance": 12000, "duration": 3600 }),
        json!({ "sport": "strength", "blocks": [
            { "kind": "exercise", "name": "squat", "sets": [{ "reps": 5, "weight": 100 }] },
            { "kind": "exercise", "name": "plank", "sets": [{ "duration": 45 }] },
        ]}),
        json!({ "sport": "strength" }),
    ]
}

#[test]
fn up_turns_intervals_and_exercises_into_blocks_in_order() {
    let mut conn = shadow(&old_bodies());
    conn.batch_execute(UP).expect("up");
    for table in ["training_session", "training_preset"] {
        let migrated = bodies(&mut conn, table);
        assert_eq!(migrated, new_bodies(), "{table}");
        for body in migrated {
            let parsed: SessionBody =
                serde_json::from_value(body.clone()).unwrap_or_else(|err| panic!("{err}: {body}"));
            assert!(parsed.accepted(), "{body}");
        }
    }

    // Running it again changes nothing.
    conn.batch_execute(UP).expect("up again");
    assert_eq!(bodies(&mut conn, "training_session"), new_bodies());
}

#[test]
fn down_restores_the_old_shape_and_drops_steady_blocks() {
    let mut rows = new_bodies();
    rows.push(json!({ "sport": "run", "distance": 11200, "duration": 3300, "blocks": [
        { "kind": "steady", "duration": 900, "name": "warmup" },
        { "kind": "repeats", "repetitions": 5, "distance": 1000, "duration": 210, "recovery": 90 },
        { "kind": "steady", "duration": 600, "name": "cooldown" },
    ]}));
    let mut conn = shadow(&rows);
    conn.batch_execute(DOWN).expect("down");

    let mut expected = old_bodies();
    expected[2] = json!({ "sport": "ski", "distance": 12000, "duration": 3600 });
    expected.push(
        json!({ "sport": "run", "distance": 11200, "duration": 3300, "intervals": [
            { "repetitions": 5, "distance": 1000, "duration": 210, "recovery": 90 },
        ]}),
    );
    for table in ["training_session", "training_preset"] {
        assert_eq!(bodies(&mut conn, table), expected, "{table}");
    }
}
