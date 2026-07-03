FROM localhost/cityapp:php
LABEL maintainer="Luke Przybylski <lprzybylski@paloaltonetworks.com>"
LABEL description="CityApp + Summon/summon-conjur, for the Kubernetes Authenticator Client (JWT sidecar) demo"
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN curl -sSfL https://github.com/cyberark/summon/releases/download/v0.11.0/summon-linux-amd64.tar.gz -o /tmp/summon.tar.gz \
    && tar -xzf /tmp/summon.tar.gz -C /usr/local/bin summon \
    && chmod +x /usr/local/bin/summon \
    && rm /tmp/summon.tar.gz
RUN mkdir -p /usr/local/lib/summon \
    && curl -sSfL https://github.com/cyberark/summon-conjur/releases/download/v0.9.3/summon-conjur-linux-amd64.tar.gz -o /tmp/summon-conjur.tar.gz \
    && tar -xzf /tmp/summon-conjur.tar.gz -C /usr/local/lib/summon summon-conjur \
    && chmod +x /usr/local/lib/summon/summon-conjur \
    && rm /tmp/summon-conjur.tar.gz
ENTRYPOINT ["/usr/local/bin/summon", "-f", "/etc/summon/secrets.yml", "/usr/local/bin/apache2-foreground"]
