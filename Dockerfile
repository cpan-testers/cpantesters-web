FROM cpantesters:base
COPY ./ ./
RUN dzil authordeps --missing | cpanm -v --notest
RUN dzil listdeps --missing | cpanm -v --notest
RUN dzil install --install-command "cpanm -v ."
COPY ./etc/docker/web/my.cnf ./.cpanstats.cnf
CMD [ "cpantesters-web", "daemon" ]
EXPOSE 3000
