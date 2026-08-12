FROM eclipse-temurin:21-jre-jammy

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ARG FUSEKI_VERSION=6.2.0
ARG FUSEKI_SHA512=ba65f5867d2d4741b2ed9e2af5a0d4fbb447909894ab2a0c6bc4dac8997f4fe339c87b13c48d45d054977769f0f8bf763ea346b1f7792d5cdc458041bd43a132

WORKDIR /opt
RUN curl -fsSLo fuseki.tar.gz \
      "https://archive.apache.org/dist/jena/binaries/apache-jena-fuseki-${FUSEKI_VERSION}.tar.gz" && \
    echo "${FUSEKI_SHA512}  fuseki.tar.gz" | sha512sum -c - && \
    tar xzf fuseki.tar.gz && \
    mv "apache-jena-fuseki-${FUSEKI_VERSION}" fuseki && \
    rm fuseki.tar.gz

WORKDIR /opt/fuseki

EXPOSE 3030

CMD ["/bin/bash"]
