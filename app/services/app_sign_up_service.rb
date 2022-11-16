# frozen_string_literal: true

class AppSignUpService < BaseService
  def call(app, remote_ip, params)
    @app       = app
    @remote_ip = remote_ip
    @params    = params

    raise Mastodon::NotPermittedError
  end
end
