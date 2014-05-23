FROM	dockerfile/ruby
MAINTAINER	roygobeil.antoine@gmail.com

# Update
RUN apt-get -y update

# Install supervisor and redis
RUN apt-get -y install supervisor redis-server

RUN mkdir /opt/app

# Install dep
ADD Gemfile /opt/app/
ADD Gemfile.lock /opt/app/

# Install dependencies
RUN cd /opt/app; /usr/bin/bundle install --deployment --binstubs

# Add src
ADD . /opt/app

# Add supervisor conf
ADD ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose nginx and redis
EXPOSE  4000
EXPOSE  6379

# Start supervisor
CMD ["supervisord", "-n"]