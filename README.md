# nginx_auth_backend

Authentication backend to use in conjunction with Nginx

## What is it?

It is a simple Sinatra application that authenticates user via IP address, an authkey parameter sent along the requested URL or with Google's OAuth2 endpoint using Omniauth. Whenever a request comes in, it checks regex expressions stored in Redis that are associated with the user and checks whether any of them match the requested URL. If one does, it instructs Nginx to serve the request.

Read this [blog post](http://antoineroygobeil.com/blog/2014/2/6/nginx-ruby-auth/) for more information.

## Configuration

Update the config.yml with your settings.

### cookie
#### secret
Secret for the cookie

  openssl rand -base64 128
  
#### domain
Domain for the cookie. You may want to set a wildcard domain.

### auth_domain
Domain where this authentication app will run

### redis
Connection for Redis

### cache
#### cookie
Time in seconds to cache authentication check via cookie

#### host
Time in seconds to cache authorization and mapping for a given host

## Build Docker image
sudo docker build -t nginx_auth_backend .

## Usage
To run commands on your Redis server you can use:
sudo docker run nginx_auth_backend cli redis_command

### Add mapping
hset graphite.antoineroygobeil.com url http://127.0.0.1

### Make endpoint public (a blog for example)
hset graphite.antoineroygobeil.com public true

### Grant access based on user's email
sadd email:roygobeil.antoine@gmail.com ^photo.*

### Grant access based on IP or netmask
sadd ip:192.168.1.0/24 ^sickbeard\.antoineroygobeil\.com*

### Expire access
Using Redis EXPIRE on a key is a great way of temporarily grant access!

## Nginx configuration

Check the [example Nginx config](example_nginx_config) this application expects.
