mod bot;
mod commands;

use log::{error, info};
use poise::Framework;
use serenity::all::ClientBuilder;
use shuttle_runtime::SecretStore;
use songbird::SerenityInit;
use spoticord_database::Database;
use std::env;

#[shuttle_runtime::main]
async fn main(
    #[shuttle_runtime::Secrets] secret_store: SecretStore,
) -> Result<shuttle_serenity::SerenityService, shuttle_runtime::Error> {
    _ = rustls::crypto::aws_lc_rs::default_provider().install_default();

    if std::env::var("RUST_LOG").is_err() {
        #[cfg(debug_assertions)]
        std::env::set_var("RUST_LOG", "spoticord");

        #[cfg(not(debug_assertions))]
        std::env::set_var("RUST_LOG", "spoticord=info");
    }

    // Shuttle runtime already installs a global tracing/logging subscriber.
    // Using init() after another logger is set causes a panic (SetLoggerError).
    // try_init() will silently ignore if a logger is already installed.
    let _ = env_logger::try_init();

    info!("Today is a good day!");
    info!(" - Spoticord");

    // --- Load secrets ---
    // Load .env for local dev fallbacks
    let _ = dotenvy::dotenv();

    // Helper closure to fetch a key from SecretStore if present else env
    let get_secret = |key: &str| -> Option<String> {
        if let Some(v) = secret_store.get(key) {
            return Some(v);
        }
        env::var(key).ok()
    };

    let discord_token = get_secret("DISCORD_TOKEN").expect("Missing DISCORD_TOKEN");
    let database_url = get_secret("DATABASE_URL").expect("Missing DATABASE_URL");
    let link_url = get_secret("LINK_URL").expect("Missing LINK_URL");
    let spotify_client_id = get_secret("SPOTIFY_CLIENT_ID").expect("Missing SPOTIFY_CLIENT_ID");
    let spotify_client_secret =
        get_secret("SPOTIFY_CLIENT_SECRET").expect("Missing SPOTIFY_CLIENT_SECRET");

    // Optional
    let kv_url = get_secret("KV_URL");
    let guild_id = get_secret("GUILD_ID");

    // --- Set environment variables for spoticord_config ---
    env::set_var("DISCORD_TOKEN", &discord_token);
    env::set_var("DATABASE_URL", &database_url);
    env::set_var("LINK_URL", &link_url);
    env::set_var("SPOTIFY_CLIENT_ID", &spotify_client_id);
    env::set_var("SPOTIFY_CLIENT_SECRET", &spotify_client_secret);

    // Set optional environment variables if they exist
    if let Some(kv_url) = kv_url {
        env::set_var("KV_URL", kv_url);
    }
    if let Some(guild_id) = guild_id {
        env::set_var("GUILD_ID", guild_id);
    }

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
        .setup(|ctx, ready, framework| Box::pin(bot::setup(ctx, ready, framework, database)))
        .options(bot::framework_opts())
        .build();

    let client = match ClientBuilder::new(&discord_token, spoticord_config::discord_intents())
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
