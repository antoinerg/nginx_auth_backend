FROM	ruby
MAINTAINER	roygobeil.antoine@gmail.com

# Update
RUN apt-get -y update

RUN apt-get install -y redis-server

RUN mkdir /opt/app

# Install dep
ADD Gemfile /opt/app/
ADD Gemfile.lock /opt/app/

# Install dependencies
RUN cd /opt/app; bundle install --deployment --binstubs

# Add src
ADD . /opt/app

# Expose thin
EXPOSE  4000

env PATH /opt/app/bin:$PATH

WORKDIR /opt/app

CMD ["/opt/app/bin/thin","-c","/opt/app","-e","production","-p","4000","start"]
