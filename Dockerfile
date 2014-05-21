FROM	dockerfile/ruby

# Update
RUN apt-get -y update

# Install supervisor and redis
RUN apt-get -y install supervisor redis-server

# Manually add src
RUN mkdir /data/app
ADD . /data/app

# Install dependencies
RUN cd /data/app; /usr/bin/bundle install --deployment --binstubs;ls
#RUN cd /data/app;bundle install;pwd

# Add supervisor conf
ADD ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose nginx and redis
EXPOSE  80
EXPOSE  443
EXPOSE  6379

# Start supervisor
CMD ["supervisord", "-n"]
