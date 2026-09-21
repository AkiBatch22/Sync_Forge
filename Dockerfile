# syntax=docker/dockerfile:1
ARG RUBY_VERSION=4.0.7

FROM ruby:${RUBY_VERSION}-slim AS base
WORKDIR /rails
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libpq5 libvips postgresql-client && \
    rm -rf /var/lib/apt/lists/*
ENV BUNDLE_PATH=/usr/local/bundle \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

FROM base AS build-base
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev && \
    rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./

FROM build-base AS development
RUN bundle install
COPY . .
RUN bundle exec bootsnap precompile --gemfile app/ lib/
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]

FROM build-base AS production-build
ENV BUNDLE_WITHOUT=development:test
RUN bundle install && \
    rm -rf /root/.bundle /usr/local/bundle/ruby/*/cache
COPY . .
RUN bundle exec bootsnap precompile --gemfile app/ lib/

FROM base AS production
ENV RAILS_ENV=production \
    RACK_ENV=production \
    BUNDLE_WITHOUT=development:test
RUN groupadd --system --gid 1000 rails && \
    useradd --system --uid 1000 --gid 1000 --create-home rails
COPY --from=production-build --chown=rails:rails /usr/local/bundle /usr/local/bundle
COPY --from=production-build --chown=rails:rails /rails /rails
USER rails:rails
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl --fail --silent http://127.0.0.1:3000/health || exit 1
EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
