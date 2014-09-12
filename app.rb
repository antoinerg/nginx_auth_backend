require "sinatra/base"
require 'sinatra/synchrony'
require "omniauth-openid"
require "sinatra/config_file"
require "sinatra/multi_route"

require 'redis/connection/hiredis'
require 'redis/connection/synchrony'
require 'redis'
require 'rack/fiber_pool'

require 'uri'

class Auth < Sinatra::Base
  set :protection, :except => :path_traversal
  register Sinatra::ConfigFile
  config_file 'config/config.yml'

  register Sinatra::MultiRoute

  def initialize
    super
    @redis = EventMachine::Synchrony::ConnectionPool.new(size: 4) do
      Redis.new(:url => settings.redis_url)
    end
  end

  # Use a wildcard cookie to achieve single sign-on for all subdomains
  use Rack::Session::Cookie, :secret => settings.cookie["secret"],
    :domain => settings.cookie["domain"],
    :secure => true

  # Perform authentication against Google OpenID endpoint
  use OmniAuth::Builder do
    provider :open_id, :name => 'google', :identifier => 'https://www.google.com/accounts/o8/id'
  end

  # Catch all requests
  route :get, :post, '*' do   
    #
    if request.host == settings.auth_domain
      if request.scheme == "http"
        headers "X-Accel-Redirect" => "/secure"
        return ""
      end
      pass
    end

    # Do we have a mapping for this
    if url = map(request)
    else
      status 404
      return  erb :nothing
    end

    # Secure website
    if secure?(request)
      if request.scheme == "http"
        headers "X-Accel-Redirect" => "/secure"
        return ""
      end

      # Authenticate user
      unless authenticated?
        redirect settings.auth_domain_proto + "://" + settings.auth_domain + "/?origin=" + CGI.escape(request.url)
      end

      # If authorized, serve request
      if authorized?(request)
        headers "X-Remote-User" => session[:email]
      else
        status 403
        return erb :forbidden
      end
    end

    headers "X-Reproxy-URL" => url+request.fullpath
    headers "X-Accel-Redirect" => "/reproxy"
    return ""
  end

  # Block that is called back when authentication is successful
  process = lambda do
    auth = request.env['omniauth.auth']
    session[:logged] = true
    session[:provider] = auth.provider
    session[:uid] = auth.uid
    session[:name] = auth.info.name
    session[:email] = auth.info.email
    
    # Check IP
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
    @origin = CGI.unescape(params[:origin])
    @authenticated = authenticated?
    erb :login
  end

  def map(req)
    url = @redis.hget(req.host,"url")
    puts url
    return url
  end

  def secure?(req)
    secure = @redis.hget(req.host,"secure") == "false" ? false:true
    puts secure
    return secure
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
  def authorized?(req)
    host = req.host
    # Check whether the email address is authorized
    return @redis.sismember("acl:#{host}",session[:email])
  end
end
