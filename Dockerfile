FROM cpantesters/schema
RUN cpanm -v \
    CSS::Minifier::XS \
    JavaScript::Minifier::XS \
    Mojolicious \
    Mojolicious::Plugin::OAuth2 \
    Mojolicious::Plugin::AssetPack \
    Mojolicious::Plugin::Yancy

COPY ./ ./
RUN dzil authordeps --missing | cpanm -v --notest
RUN dzil listdeps --missing | cpanm -v --notest
RUN dzil install --install-command "cpanm -v ."

COPY ./etc/docker/web/my.cnf ./.cpanstats.cnf
COPY ./etc/docker/web/web.development.conf ./
ENV MOJO_HOME=./
CMD [ "cpantesters-web", "daemon" ]
EXPOSE 3000
