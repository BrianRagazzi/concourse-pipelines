FROM harbor.lab.brianragazzi.com/cache/ubuntu:latest

RUN apt-get update && apt-get upgrade -y && apt install -y git nano curl unzip zip gnupg tar wget
RUN curl -s "https://get.sdkman.io" | bash

# this SHELL command is needed to allow using source
SHELL ["/bin/bash", "-c"]    

RUN source "/root/.sdkman/bin/sdkman-init.sh" \
    && sdk install java 21.0.7-oracle \
    && sdk use java 21.0.7-oracle -y \
    && sdk install maven 3.9.9 \
    && sdk use maven 3.9.9 -y \
    && rm -rf $HOME/.sdkman/archives/* \
    && rm -rf $HOME/.sdkman/tmp/*

# Ensure sdk, mvn, and java are in the PATH for all shells
ENV PATH="/root/.sdkman/candidates/maven/current/bin:/root/.sdkman/candidates/java/current/bin:/root/.sdkman/bin:${PATH}"

# Add the Cloud Foundry GPG key
RUN curl -fsSL https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | gpg --dearmor -o /usr/share/keyrings/cloudfoundry-keyring.gpg
# Add the Cloud Foundry repository
RUN echo "deb [signed-by=/usr/share/keyrings/cloudfoundry-keyring.gpg] https://packages.cloudfoundry.org/debian stable main" | tee /etc/apt/sources.list.d/cloudfoundry.list
RUN apt update && apt install --yes cf8-cli
# Verify installation
RUN cf8 version

ADD https://github.com/pivotal-cf/om/releases/download/7.16.0/om-linux-amd64-7.16.0.tar.gz /
RUN tar -xvf  ./om-linux-amd64-7.16.0.tar.gz -C /usr/local/bin/ && rm ./om-linux-amd64-7.16.0.tar.gz
# -o /usr/local/bin/om && chmod +x /usr/local/bin/om

ENV NODE_VERSION=20
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN bash -c "source $NVM_DIR/nvm.sh && nvm install $NODE_VERSION"

# set ENTRYPOINT for reloading nvm-environment
ENTRYPOINT ["bash", "-c", "source $NVM_DIR/nvm.sh && exec \"$@\"", "--"]

# set cmd to bash
CMD ["/bin/bash"]