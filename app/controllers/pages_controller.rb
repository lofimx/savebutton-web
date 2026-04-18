class PagesController < ApplicationController
  allow_unauthenticated_access only: [ :home, :get_the_apps, :oauth_extension_callback ]

  def home
    redirect_to app_everything_path if authenticated?
  end

  def get_the_apps
  end

  def oauth_extension_callback
  end
end
