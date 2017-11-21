FROM ruby:alpine

RUN apk update && apk upgrade && apk --update add --virtual build-dependencies \
    openssl-dev \
    build-base \
    libc-dev

COPY ./ ~/VMAX-Graphite/

WORKDIR ~/VMAX-Graphite

RUN gem install bundler && bundle install

CMD ["./collector.rb"]
