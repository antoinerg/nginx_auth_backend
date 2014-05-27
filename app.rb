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
      redirect settings.auth_domain_proto + "://" + settings.auth_domain + "/?origin=" + request.url
    end

    # If authorized, serve request
    if url = authorized?(request.host)
      headers "X-Remote-User" => session[:email]
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
    if request.env.has_key? 'HTTP_X_FORWARDED_FOR'
      session[:remote_ip] = request.env['HTTP_X_FORWARDED_FOR']
    else
      session[:remote_ip] = request.env['HTTP_X_REAL_IP']
    end
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
    check_remote_ip = nil
    if request.env.has_key? 'HTTP_X_FORWARDED_FOR'
      check_remote_ip = request.env['HTTP_X_FORWARDED_FOR']
    else
      check_remote_ip = request.env['HTTP_X_REAL_IP']
    end
    if session[:logged] == true and session[:remote_ip] == check_remote_ip
      return true
    else
      return false
    end
  end

  # Return internal URL or false if unauthorized
  def authorized?(host)
    authorized = false
    # Check whether the email address is authorized
    if ! session.has_key? :email
      return false
    end
    split_email_address = session[:email].split('@')
    if defined? settings.allowed_email_domains and settings.allowed_email_domains.include? split_email_address.last
      authorized = true
    elsif defined? settings.allowed_email and settings.allowed_email.include? session[:email]
      authorized = true
    end
    if authorized == true and settings.routing.has_key? host
      return settings.routing[host]
    else
      return false
    end
  end
end
