FROM eclipse-temurin:17-jre-jammy

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        curl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/bsbm

COPY tools/test-driver/generate tools/test-driver/testdriver tools/test-driver/qualification ./
COPY tools/test-driver/lib ./lib
COPY tools/test-driver/queries ./queries
COPY tools/test-driver/usecases ./usecases
COPY tools/test-driver/givennames.txt tools/test-driver/titlewords.txt tools/test-driver/log4j.xml ./

RUN chmod +x generate testdriver qualification

CMD ["/bin/bash"]
