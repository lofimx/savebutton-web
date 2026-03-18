Rails.application.config.middleware.use OmniAuth::Builder do
  credentials = Rails.application.credentials

  # Google OAuth2
  provider :google_oauth2,
    credentials.dig(:google, :client_id) || ENV["GOOGLE_CLIENT_ID"],
    credentials.dig(:google, :client_secret) || ENV["GOOGLE_CLIENT_SECRET"],
    {
      scope: "email,profile",
      prompt: "select_account",
      image_aspect_ratio: "square",
      image_size: 120
    }

  # Apple Sign In
  provider :apple,
    ENV["APPLE_CLIENT_ID"],
    "",
    {
      scope: "email name",
      team_id: ENV["APPLE_TEAM_ID"],
      key_id: ENV["APPLE_KEY_ID"],
      pem: ENV["APPLE_PRIVATE_KEY"]
    }

  # Microsoft OAuth2
  # Use 'common' tenant to support both organizational and personal accounts
  # Use 'consumers' for personal accounts only, 'organizations' for work/school only
  provider :microsoft_graph,
    credentials.dig(:microsoft, :client_id) || ENV["MICROSOFT_CLIENT_ID"],
    credentials.dig(:microsoft, :client_secret) || ENV["MICROSOFT_CLIENT_SECRET"],
    {
      # scope: "openid email profile",
      tenant: "common"
    }
end

# Configure OmniAuth for Rails CSRF protection
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true
