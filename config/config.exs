# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :historia_live,
  ecto_repos: [HistoriaLive.Repo]

# Configures the endpoint
config :historia_live, HistoriaLiveWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "sRYHkcKFp9/rRcfIQ6+RvFXIBiGh6k5y8X8cOVCMjhT19Hk/Uz+1p2+Ma+0aZxvq",
  render_errors: [view: HistoriaLiveWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: HistoriaLive.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :phoenix, :template_engines,
  slim: PhoenixSlime.Engine,
  slime: PhoenixSlime.Engine

config :historia_live, HistoriaLive.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: "smtp.fastmail.com",
  hostname: "thinkingco.de",
  port: 465,
  username: {:system, "SMTP_USERNAME"},
  password: {:system, "SMTP_PASSWORD"},
  tls: :if_available,
  # or {:system, "ALLOWED_TLS_VERSIONS"} w/ comma seprated values (e.g. "tlsv1.1,tlsv1.2")
  allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
  ssl: false,
  retries: 1,
  no_mx_lookups: false,
  # can be `:always`. If your smtp relay requires authentication set it to `:always`.
  auth: :if_available

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
