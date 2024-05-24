use serde::Serialize;
use uuid::Uuid;

#[derive(Serialize)]
pub struct UserSettings {
  pub auth: Option<Auth>
}

#[derive(Serialize)]
pub struct Auth {
  pub user_id: Uuid
}