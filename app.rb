require "sinatra/base"
require "omniauth-openid"
require "sinatra/config_file"

class Auth < Sinatra::Base
  register Sinatra::ConfigFile
  config_file 'config/config.yml'

  # Use a wildcard cookie to achieve single sign-on for all subdomains
  use Rack::Session::Cookie, :secret => settings.cookie["secret"],
                             :domain => settings.cookie["domain"]
  
  # Perform authentication against Google OpenID endpoint
  use OmniAuth::Builder do
    provider :open_id, :name => 'google', :identifier => 'https://www.google.com/accounts/o8/id'
  end

  # Catch all requests
  get '*' do
    pass if request.host == settings.auth_domain
    # Authenticate user
    unless authenticated?
      redirect "https://" + settings.auth_domain + "/?origin=" + request.url
    end

    # If authorized, serve request
    if url = authorized?(request.host)
      headers "X-Reproxy-URL" => url + request.fullpath
      headers "X-Accel-Redirect" => "/reproxy"
      return ""
    else
      status 403
      erb :forbidden
    end
  end

  # Block that is called back when authentication is successful
  process = lambda do
    auth = request.env['omniauth.auth']
    session[:logged] = true
    session[:provider] = auth.provider
    session[:uid] = auth.uid
    session[:name] = auth.info.name
    session[:email] = auth.info.email
    redirect request.env['omniauth.origin'] || "/"
  end

  get '/auth/:name/callback', &process
  post '/auth/:name/callback', &process

  get '/logout' do
    session.clear
    redirect "/"
  end

  get '/' do
    @origin = params[:origin]
    @authenticated = authenticated?
    erb :login
  end

  def authenticated?
    if session[:logged]
      return true
    else
      return false
    end
  end

  # Return internal URL or false if unauthorized
  def authorized?(host)
    # Check whether the email address is authorized
    if settings.allowed_email.include?(session[:email]) & settings.routing.key?(host)
      return settings.routing[host]
    else
      return false
    end
  end
end
