module AccountsHelper
  def provider_name(provider)
    case provider
    when "google_oauth2" then "Google"
    when "apple" then "Apple"
    when "microsoft_graph" then "Microsoft"
    else provider.titleize
    end
  end

  def provider_icon(provider)
    case provider
    when "google_oauth2"
      render "shared/google_icon"
    when "apple"
      render "shared/apple_icon"
    when "microsoft_graph"
      render "shared/microsoft_icon"
    end
  end
end
