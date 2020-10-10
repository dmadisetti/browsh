FROM bitnami/minideb:stretch as build

RUN install_packages \
      curl \
      ca-certificates \
      git \
      autoconf \
      automake \
      g++ \
      protobuf-compiler \
      zlib1g-dev \
      libncurses5-dev \
      libssl-dev \
      pkg-config \
      libprotobuf-dev \
      make

# Install Golang
ENV GOROOT=/go
ENV GOPATH=/go-home
ENV PATH=$GOROOT/bin:$GOPATH/bin:$PATH
RUN curl -L -o go.tar.gz https://dl.google.com/go/go1.15.2.linux-amd64.tar.gz
RUN mkdir -p $GOPATH/bin
RUN tar -C / -xzf go.tar.gz

ENV BASE=$GOPATH/src/browsh/interfacer
WORKDIR $BASE
ADD interfacer $BASE

# Build Browsh
RUN $BASE/contrib/build_browsh.sh

# Set up a working environment
ENV HOME=/app
WORKDIR /app

RUN install_packages \
      xvfb \
      libgtk-3-0 \
      curl \
      ca-certificates \
      bzip2 \
      libdbus-glib-1-2 \
      procps

ENV NVM_DIR=$HOME/.nvm
RUN mkdir $NVM_DIR
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
ENV NODE_VERSION=10.7.0
RUN . "$NVM_DIR/nvm.sh" && nvm install "${NODE_VERSION}" && nvm alias default "${NODE_VERSION}" && nvm use default
ENV NODE_PATH="${NVM_DIR}/versions/node/v${NODE_VERSION}/lib/node_modules"
ENV PATH="${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:${PATH}"
RUN ls $NVM_DIR/versions/node/
RUN ls ${NVM_DIR}/versions/node/v${NODE_VERSION}/

ADD webext ${HOME}/webext
RUN npm install install -g --ignore-scripts web-ext webpack-cli
RUN npm install $HOME/webext

# Block ads, etc. This includes porn just because this image is also used on the
# public SSH demo: `ssh brow.sh`.
RUN curl -o /etc/hosts https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn-social/hosts

# Add files prior to user change
ADD interfacer/contrib/setup_firefox.sh .
ADD .travis.yml .

# Don't use root
RUN useradd -m user --home /app
RUN chown -R user:user /app ./*
USER user

# Setup Firefox
VOLUME /app/.mozilla
ENV PATH="${HOME}/bin/firefox:${PATH}"
RUN ./setup_firefox.sh
RUN rm setup_firefox.sh && rm .travis.yml

# Firefox behaves quite differently to normal on its first run, so by getting
# that over and done with here when there's no user to be dissapointed means
# that all future runs will be consistent.
RUN TERM=xterm script \
  --return \
  -c "/app/browsh" \
  /dev/null \
  >/dev/null & \
  sleep 10

RUN git init /app/
ENV GIT_DISCOVERY_ACROSS_FILESYSTEM=1
VOLUME /app/webext
VOLUME /app/interfacer

CMD web-ext run --verbose -s webext/dist/ --firefox "${HOME}/webext/firefox" --keep-profile-changes --firefox-profile=browsh > /dev/null  2>&1 & go run /go-home/src/browsh/interfacer/src/main.go --firefox.use-existing --debug
