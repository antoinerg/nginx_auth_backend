# nginx_auth_backend

Authentication backend to use in conjunction with Nginx

## What is it?

It is a simple Sinatra application that authenticates user via Google's OpenID endpoint using Omniauth. Whenever a request comes in, it checks whether the user's email is whitelisted and if so, instructs Nginx to serve the request.

Read this [blog post](http://antoineroygobeil.com/blog/2014/2/6/nginx-ruby-auth/) for more information.

## Configuration

Update the config.yml with your settings.

### cookie
#### secret
Secret for the cookie
#### domain
Domain for the cookie. You may want to set a wildcard domain.

### auth_domain_proto
Protocol used for authentication app, http or https

### auth_domain
Domain where this authentication app will run

### allowed_email_domains
List of email domains for which access is granted. Can be used in combination with or separate to allowed_email

### allowed_email
List of specific email addresses to which access is granted. Can be used in combination with or separate to allowed_email_domains

### routing
Key-value that maps a public hostname to an internal location Nginx will serve
