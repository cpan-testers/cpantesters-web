FROM cpantesters/schema

# Default debian image tries to clean APT after an install. We're using
# cache mounts instead, so we do not want to clean it.
RUN rm -f /etc/apt/apt.conf.d/docker-clean

RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt update && \
    apt install -y nodejs npm

# Load some modules that will always be required, to cut down on docker
# rebuild time
RUN --mount=type=cache,target=/root/.cpanm \
  cpanm -v --notest \
    CSS::Minifier::XS \
    JavaScript::Minifier::XS \
    Mojolicious \
    Mojolicious::Plugin::OAuth2 \
    Mojolicious::Plugin::AssetPack \
    Mojolicious::Plugin::Yancy

# Load last version's modules, to again cut down on rebuild time
COPY ./cpanfile /app/cpanfile
RUN --mount=type=cache,target=/root/.cpanm \
  cpanm --installdeps --notest .

COPY ./ /app
RUN --mount=type=cache,target=/root/.cpanm \
  --mount=type=cache,target=/root/.npm \
  dzil authordeps --missing | cpanm -v --notest && \
  dzil listdeps --missing | cpanm -v --notest && \
  cd share && npm install && cd .. && \
  dzil install --install-command "cpanm -v --notest ."

COPY ./etc/docker/web/web.development.conf /app
ENV MOJO_HOME=/app
CMD [ "cpantesters-web", "daemon" ]
EXPOSE 3000
VOLUME /app
