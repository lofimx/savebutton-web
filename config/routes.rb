Rails.application.routes.draw do
  # API
  namespace :api do
    namespace :v1 do
      # Device auth (PKCE flow + token management)
      get "auth/authorize", to: "auth#authorize"
      get "auth/authorize/callback", to: "auth#authorize_callback", as: "auth_authorize_callback"
      get "auth/authorize/register", to: "auth_pages#register", as: "auth_authorize_register"
      get "auth/authorize/:provider", to: "auth_pages#provider", as: "auth_authorize_provider"
      post "auth/token", to: "auth#token"
      post "auth/revoke", to: "auth#revoke"

      get "handshake", to: "handshake#show"
      scope ":user_email", constraints: { user_email: /[^\/]+/ } do
        resources :anga, only: [ :index ], controller: "anga", as: "user_anga"
        get "anga/:filename", to: "anga#show", as: "user_anga_file", constraints: { filename: /[^\/]+/ }
        post "anga/:filename", to: "anga#create", constraints: { filename: /[^\/]+/ }

        # Meta API for anga metadata (tags, notes)
        resources :meta, only: [ :index ], controller: "meta", as: "user_meta"
        get "meta/:filename", to: "meta#show", as: "user_meta_file", constraints: { filename: /[^\/]+/ }
        post "meta/:filename", to: "meta#create", constraints: { filename: /[^\/]+/ }

        # Words API for full-text search plaintext copies
        get "words", to: "words#index", as: "words"
        get "words/:anga", to: "words#show", as: "words_anga", constraints: { anga: /[^\/]+/ }
        get "words/:anga/:filename", to: "words#file", as: "words_file", constraints: { anga: /[^\/]+/, filename: /[^\/]+/ }

        # Share API for generating public share URLs
        post "share/anga/:filename", to: "share#create", as: "share_anga_file", constraints: { filename: /[^\/]+/ }

        # Cache API for bookmark webpage caching
        get "cache", to: "cache#index", as: "cache"
        get "cache/:bookmark", to: "cache#show", as: "cache_bookmark", constraints: { bookmark: /[^\/]+/ }
        get "cache/:bookmark/:filename", to: "cache#file", as: "cache_file", constraints: { bookmark: /[^\/]+/, filename: /[^\/]+/ }
      end
    end
  end

  # Authentication
  resource :session
  resource :registration, only: [ :new, :create ]
  resources :passwords, param: :token

  # Account management
  resource :account, only: [ :show, :update ] do
    delete "identities/:identity_id", to: "accounts#destroy_identity", as: :identity
    delete "device_tokens/:device_token_id", to: "accounts#destroy_device_token", as: :device_token
    patch "avatar", to: "accounts#update_avatar"
  end

  # OmniAuth routes - support both GET and POST callbacks
  # (Google uses GET, some providers use POST)
  get "/auth/:provider/callback", to: "omniauth_callbacks#create"
  post "/auth/:provider/callback", to: "omniauth_callbacks#create"
  get "/auth/failure", to: "omniauth_callbacks#failure"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Public share routes (unauthenticated)
  get "share/:user_id/anga/:filename", to: "shares#show", as: "share_anga", constraints: { filename: /[^\/]+/ }

  # App routes (authenticated)
  scope "/app", as: "app" do
    get "/", to: redirect("/app/everything")
    get "everything", to: "everything#index"
    get "anga/:id/preview", to: "anga#preview", as: "anga_preview"
    get "anga/:id/meta", to: "anga#meta", as: "anga_meta"
    post "anga/:id/meta", to: "anga#save_meta", as: "anga_save_meta"
    get "anga/:id/cache_status", to: "anga#cache_status", as: "anga_cache_status"
    get "anga/:id/cache/:filename", to: "anga#cache_file", as: "anga_cache_file", constraints: { filename: /[^\/]+/ }
    post "anga", to: "anga#create", as: "anga_create"
  end

  # Static pages
  get "get-the-apps", to: "pages#get_the_apps", as: :get_the_apps

  # Homepage
  root "pages#home"
end
