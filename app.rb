require "sinatra/base"
require 'sinatra/synchrony'
require 'omniauth-google-oauth2'
require "sinatra/config_file"

require 'redis/connection/hiredis'
require 'redis/connection/synchrony'
require 'redis'
require 'rack/fiber_pool'

require 'uri'
require 'ipaddr'

$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG

class Auth < Sinatra::Base
  set :protection, :except => :path_traversal
  set :static, :false
  register Sinatra::ConfigFile
  config_file 'config/config.yml'

  def initialize
    super
    @redis = EventMachine::Synchrony::ConnectionPool.new(size: 4) do
      Redis.new(:host => settings.redis["host"],:port=>settings.redis["port"],:db=>settings.redis["db"])
    end
  end

  # Use a wildcard cookie to achieve single sign-on for all subdomains
  use Rack::Session::Cookie, :secret => settings.cookie["secret"],
    :domain => settings.cookie["domain"],
    :secure => true

  google = settings.providers["google"]
  # Perform authentication against Google OpenID endpoint
  use OmniAuth::Builder do
    provider :google_oauth2, google["client_id"], google["client_secret"]
  end

  # Set X-Remote-User if user is logged in
  get "/check" do
    headers "Cache-Control" => "max-age=#{settings.cache["cookie"]}"
    if authenticated?
      headers "X-Remote-User" => session[:email]
      return ""
    else
      headers "X-Remote-User" => "anonymous"
      return ""
    end
  end

  # Map host and apply ACL
  get '/host' do
    headers "Cache-Control" => "max-age=#{settings.cache["host"]}"
    $log.debug("Method: #{request.env["HTTP_X_METHOD"]}")
    # Do we have a mapping for this
    if url = map(request)
      $log.debug("Mapping to: #{url}")
    else
      status 404
      return erb :nothing
    end

    unless public?(request)
      # Site is not public
      headers "Vary" => "X-Remote-User, X-Forwarded-For, X-Method"
      unless request.env["HTTP_X_METHOD"].downcase == "options"
      unless ip_access?(request)
        # Access by IP is denied
        if x_remote_user == "anonymous"
          # User not authenticated and site is not public so redirect
          redirect settings.auth_domain_proto + "://" + settings.auth_domain + "/?origin=" + CGI.escape(request.url)
        end

        # At this stage, user is authenticated in via omniauth
        unless authorized?(request,"email:#{x_remote_user}")
          status 403
          return erb :forbidden
        end    
      end
      end
    end

    # Reaching this point means the user is authorized
    headers "X-Reproxy-Host" => url
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
    url = CGI.escape(params[:origin]) if params[:origin]
    #referer = CGI.escape(env["HTTP_REFERER"]) if env["HTTP_REFERER"]
    #@origin = referer || url
    @origin = url
    @authenticated = authenticated?
    erb :login
  end

  def map(req)
    host = req.env['HTTP_X_FORWARDED_HOST'] || req.host
    puts "Check mapping for #{host}"
    url = @redis.hget(req.host,"url")
    return url
  end

  def ssl?(req)
    secure = @redis.hget(req.host,"ssl") == "false" ? false:true
    return secure
  end

  def public?(req)
    public = @redis.hget(req.host,"public") == "true" ? true:false
    return public
  end

  def key_access?(request)
    # Check whether the request is signed with an authentication key
    if key = params[:authkey]
      # If authorized, serve request
      return authorized?(request,"authkey:#{key}")
    end
  end

  def ip_access?(request)
    $log.debug("Checking IP access")
    check_remote_ip = nil
    if request.env.has_key? 'HTTP_X_FORWARDED_FOR'
      check_remote_ip = request.env['HTTP_X_FORWARDED_FOR']
    else
      check_remote_ip = request.env['HTTP_X_REAL_IP']
    end
    $log.debug("Remote IP is: #{check_remote_ip}")
    # Match IP with netmask
    request_ip = IPAddr.new(check_remote_ip)
    @redis.keys('ip:*').each do |i|
      ip = IPAddr.new(i.gsub(/^ip:/,''))
      if ip.include?(request_ip)
        $log.debug("IP is included in #{i}")
        if authorized?(request,i)
          $log.debug("Access authorized by IP")
          return true
        end
      end
    end

    return false
  end
end

def x_remote_user?
  #if session[:logged] == true and session[:remote_ip] == check_remote_ip
  if request.env.has_key? 'HTTP_X_REMOTE_USER'
    return true
  else
    return false
  end
end

def x_remote_user
  env["HTTP_X_REMOTE_USER"] || "anonymous"
end

def ip
  request.env['HTTP_X_FORWARDED_FOR'] || request.env['HTTP_X_REAL_IP']
end

def authenticated?
  check_remote_ip = nil
  if request.env.has_key? 'HTTP_X_FORWARDED_FOR'
    check_remote_ip = request.env['HTTP_X_FORWARDED_FOR']
  else
    check_remote_ip = request.env['HTTP_X_REAL_IP']
  end
  if session[:logged] == true # and session[:remote_ip] == check_remote_ip
  #if request.env.has_key? 'HTTP_X_REMOTE_USER'
    return true
  else
    return false
  end
end

# Return internal URL or false if unauthorized
def authorized?(request,entry)
  url = request.url.gsub(/^https?:\/\//,'')
  host = request.host
  # Check whether the email address is authorized
  @redis.smembers(entry).each do |reg|
    begin
      $log.debug("Checking #{url} versus #{reg}")
      return true if !!(Regexp.new(reg) =~ host)
    rescue
      $log.error("Malformed regex expressions in database")
    end
  end
  return false
end
