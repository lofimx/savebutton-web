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

  def device_type_label(device_type)
    case device_type
    when "mobile_android" then "Android"
    when "mobile_ios" then "iOS"
    when "browser_extension" then "Browser Extension"
    when "desktop_linux" then "Linux"
    when "desktop_macos" then "macOS"
    when "desktop_windows" then "Windows"
    else device_type.to_s.titleize
    end
  end

  def device_type_icon(device_type)
    icon_path = case device_type
    when "mobile_android", "mobile_ios"
      "M7 2a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H7zm5 18a1 1 0 1 1 0-2 1 1 0 0 1 0 2z"
    when "browser_extension"
      "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"
    else
      "M21 2H3a1 1 0 0 0-1 1v14a1 1 0 0 0 1 1h7v2H8v2h8v-2h-2v-2h7a1 1 0 0 0 1-1V3a1 1 0 0 0-1-1zm-1 14H4V4h16v12z"
    end
    tag.svg(viewBox: "0 0 24 24", width: 20, height: 20, fill: "currentColor", class: "text-neutral-400") do
      tag.path(d: icon_path)
    end
  end
end
