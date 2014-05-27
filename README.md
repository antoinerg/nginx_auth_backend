# nginx_auth_backend

Authentication backend to use in conjunction with Nginx

## What is it?

It is a simple Sinatra application that authenticates user via Google's OpenID endpoint using Omniauth. Whenever a request comes in, it checks whether the user's email is whitelisted and if so, instructs Nginx to serve the request.

Read this [blog post](http://antoineroygobeil.com/blog/2014/2/6/nginx-ruby-auth/) for more information.

## Usage

### Add mapping
hset graphite.antoineroygobeil.com url http://127.0.0.1

### Force secure endpoint
hset graphite.antoineroygobeil.com secure true

### Grant access based on user's email
sadd acl:graphite.antoineroygobeil.com roygobeil.antoine@gmail.com

## Configuration

Update the config.yml with your settings.

### cookie
#### secret
Secret for the cookie
#### domain
Domain for the cookie. You may want to set a wildcard domain.

### auth_domain
Domain where this authentication app will run

### redis_url
URL to the Redis database
