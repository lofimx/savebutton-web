class PagesController < ApplicationController
  allow_unauthenticated_access only: [ :home, :get_the_apps ]

  def home
    redirect_to app_everything_path if authenticated?
  end

  def get_the_apps
  end
end
