

```dockerfile

FROM node:24.16.0-alpine AS node-assets

WORKDIR /build


COPY package*.json ./
RUN npm ci --prefer-offline


COPY Makefile scripts ./
RUN make assets


FROM ruby:3.4.8-alpine AS builder


RUN bundle config set --global frozen true

WORKDIR /app


COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs "$(nproc)" --retry 3


COPY Makefile scripts scripts/
COPY content content/


COPY --from=node-assets /build/build/_site/assets/bower ./build/_site/assets/bower
COPY --from=node-assets /build/build/_site/css/fonts   ./build/_site/css/fonts


RUN mkdir -p ./build/_site \
 && bundle exec ./scripts/release.rss.rb \
      'https://updates.jenkins.io/release-history.json' \
      > ./build/_site/releases.rss \
 && bundle exec ./scripts/fetch-external-resources \
 && make real_generate


FROM nginx:1.25-alpine AS production


RUN addgroup -S www && adduser -S -G www www

COPY --from=builder /app/build/_site      /usr/share/nginx/html
COPY docker/default.conf                  /etc/nginx/conf.d/default.conf


RUN nginx -t

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost/ || exit 1
```

