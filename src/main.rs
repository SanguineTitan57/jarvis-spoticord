mod bot;
mod commands;

use log::{error, info};
use poise::Framework;
use serenity::all::ClientBuilder;
use shuttle_runtime::{SecretStore, ShuttleResult};
use shuttle_serenity::ShuttleSerenity;
use songbird::SerenityInit;
use spoticord_database::Database;

#[shuttle_runtime::main]
async fn main(
    #[shuttle_runtime::Secrets] secret_store: SecretStore,
) -> ShuttleResult<ShuttleSerenity> {
    // Force aws-lc-rs as default crypto provider
    _ = rustls::crypto::aws_lc_rs::default_provider().install_default();

    // Setup logging
    if std::env::var("RUST_LOG").is_err() {
        #[cfg(debug_assertions)]
        std::env::set_var("RUST_LOG", "spoticord");

        #[cfg(not(debug_assertions))]
        std::env::set_var("RUST_LOG", "spoticord=info");
    }
    env_logger::init();

    info!("Today is a good day!");
    info!(" - Spoticord");

    // --- Load secrets from Shuttle ---
    let discord_token = secret_store
        .get("DISCORD_TOKEN")
        .expect("Missing DISCORD_TOKEN");
    let database_url = secret_store
        .get("DATABASE_URL")
        .expect("Missing DATABASE_URL");
    let link_url = secret_store
        .get("LINK_URL")
        .expect("Missing LINK_URL");
    let spotify_client_id = secret_store
        .get("SPOTIFY_CLIENT_ID")
        .expect("Missing SPOTIFY_CLIENT_ID");
    let spotify_client_secret = secret_store
        .get("SPOTIFY_CLIENT_SECRET")
        .expect("Missing SPOTIFY_CLIENT_SECRET");

    // --- Database connection ---
    let database = match Database::connect_with_url(&database_url).await {
        Ok(db) => db,
        Err(why) => {
            error!("Failed to connect to database and perform migrations: {why}");
            panic!("Database connection failed");
        }
    };

    // --- Setup bot framework ---
    let framework = Framework::builder()
        .setup(|ctx, ready, framework| {
            Box::pin(bot::setup(ctx, ready, framework, database))
        })
        .options(bot::framework_opts())
        .build();

    let client = match ClientBuilder::new(
        &discord_token,
        spoticord_config::discord_intents(),
    )
    .framework(framework)
    .register_songbird_from_config(songbird::Config::default().use_softclip(false))
    .await
    {
        Ok(client) => client,
        Err(why) => {
            error!("Fatal error when building Serenity client: {why}");
            panic!("Bot init failed");
        }
    };

    Ok(client.into())
}
