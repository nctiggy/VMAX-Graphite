FROM ruby:alpine

RUN apk update && \
    apk upgrade && \
    apk --update add --virtual build-dependencies \
    openssl-dev \
    build-base \
    libc-dev && \
    gem update --no-ri --no-rdoc && \
    gem install bundler --no-ri --no-rdoc

COPY ./ ~/VMAX-Graphite/

WORKDIR ~/VMAX-Graphite

RUN bundle install &&\
    apk del build-dependencies && \
    rm -rf /var/cache/apk/* && \
    mkdir /vmax-csv

VOLUME ["/data"]

CMD ["./collector.rb"]
