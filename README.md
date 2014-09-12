# nginx_auth_backend

Authentication backend to use in conjunction with Nginx

## What is it?

It is a simple Sinatra application that authenticates user via Google's OpenID endpoint using Omniauth. Whenever a request comes in, it checks whether the user's email is whitelisted and if so, instructs Nginx to serve the request.

Read this [blog post](http://antoineroygobeil.com/blog/2014/2/6/nginx-ruby-auth/) for more information.

## Usage

### Add mapping
hset graphite.antoineroygobeil.com url http://127.0.0.1

### Force endpoint through SSL
hset graphite.antoineroygobeil.com ssl true

### Make endpoint public (a blog for example)
hset graphite.antoineroygobeil.com public true

### Grant access based on user's email
sadd email:roygobeil.antoine@gmail.com ^photo.*

### Grant access based on authkey parameter
sadd authkey:some_random_string ^graphite.* ^files.*

### Grant access based on IP or netmask
sadd ip:192.168.1.0/24 ^sickbeard\.antoineroygobeil\.com*

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
