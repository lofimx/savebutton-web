class OmniauthCallbacksController < ApplicationController
  skip_forgery_protection only: :create
  allow_unauthenticated_access only: :create

  def create
    auth = request.env["omniauth.auth"]

    begin
      if authenticated?
        # User is already logged in - link the new identity to their account
        link_identity(auth)
      else
        # User is not logged in - sign in or create account
        sign_in_with_oauth(auth)
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to (authenticated? ? account_path : new_session_path), alert: "Authentication failed: #{e.message}"
    end
  end

  def failure
    redirect_to new_session_path, alert: "Authentication failed: #{params[:message]}"
  end

  private

  def link_identity(auth)
    # Check if this identity is already linked to another user
    existing_identity = Identity.find_by(provider: auth.provider, uid: auth.uid)

    if existing_identity
      if existing_identity.user_id == Current.user.id
        redirect_to account_path, notice: "#{provider_name(auth.provider)} is already connected to your account."
      else
        redirect_to account_path, alert: "This #{provider_name(auth.provider)} account is already linked to another user."
      end
    else
      Current.user.identities.create!(provider: auth.provider, uid: auth.uid)
      redirect_to account_path, notice: "Successfully connected #{provider_name(auth.provider)}!"
    end
  end

  def sign_in_with_oauth(auth)
    user = User.from_omniauth(auth)

    # Create a new session for the user
    session = user.sessions.create!(
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    # Set the session cookie
    cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }

    redirect_to root_path, notice: "Successfully signed in with #{provider_name(auth.provider)}!"
  end

  def provider_name(provider)
    case provider.to_s
    when "google_oauth2" then "Google"
    when "apple" then "Apple"
    when "microsoft_graph" then "Microsoft"
    else provider.to_s.titleize
    end
  end
end
