use std::sync::Arc;

use tracing::info;
use training::activities::ActivityClient;
use training::clock::{Clock, OsloClock};
use training::config::load_config;
use training::database::connection::create_connection_pool;
use training::garmin::GarminClient;
use training::router::main::{init_router, AppState};

#[tokio::main]
async fn main() {
    let config = load_config();

    tracing_subscriber::fmt()
        .with_env_filter(config.log_level.clone())
        .init();

    let port = config.port.clone();
    let pool = create_connection_pool(config.database_url.clone());
    let activities: Arc<dyn ActivityClient> =
        Arc::new(GarminClient::new(config.garmin_api_key.clone()));
    let clock: Arc<dyn Clock> = Arc::new(OsloClock);
    let state = AppState {
        db: pool,
        config,
        activities,
        clock,
    };
    let nights = state.clone();
    tokio::spawn(training::schedule::nightly(nights));
    let app = init_router(state);
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}"))
        .await
        .unwrap();

    info!("Starting server on 0.0.0.0:{port}");
    axum::serve(listener, app).await.unwrap();
}
