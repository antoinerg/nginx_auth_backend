# nginx_auth_backend

Authentication backend to use in conjunction with Nginx

## What is it?

It is a simple Sinatra application that authenticates user via Google's OpenID endpoint using Omniauth. Whenever a request comes in, it checks whether the user's email is whitelisted and if so, instructs Nginx to serve the request.

Read this blog post for more information.

## Configuration

Update the config.yml with your settings.

### cookie
#### secret
Secret for the cookie
#### domain
Domain for the cookie. You may want to set a wildcard domain.

### auth_domain
Domain where this authentication app will run

### allowed_email
List of emails to which access is granted

### routing
Key-value that maps a public hostname to an internal location
