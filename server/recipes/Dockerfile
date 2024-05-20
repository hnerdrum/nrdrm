FROM haskell:9.2.8

WORKDIR /usr/src/app

COPY . .

RUN stack setup --install-ghc && stack build

EXPOSE 8000

CMD ["stack", "run"]