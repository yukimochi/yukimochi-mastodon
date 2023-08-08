# frozen_string_literal: true

module Admin::SettingsHelper
  def captcha_available?
    ENV['TURNSTILE_SECRET_KEY'].present? && ENV['TURNSTILE_SITE_KEY'].present?
  end
end
