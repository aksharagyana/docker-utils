FROM python:3.12.0a5-slim

ARG USERNAME=somebody
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# runtime dependencies
RUN  apt-get -y update \
        && update-ca-certificates \
	&& apt-get install -y --no-install-recommends curl wget uuid-dev git zip unzip tar ca-certificates curl apt-transport-https net-tools iproute2 netcat dnsutils iputils-ping iptables nmap tcpdump openssh-client \
	&& rm -rf /var/lib/apt/lists/*

RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash \
    && curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && curl -fsSL https://raw.githubusercontent.com/turbot/steampipe/main/install.sh | bash \
    && git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv \
    && echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bash_profile \
    && echo 'export PATH=$PATH:$HOME/.tfenv/bin' >> ~/.bashrc \
    && ln -s ~/.tfenv/bin/* /usr/local/bin \
    && curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update \
    && apt-get install -y kubectl

RUN cd "$(mktemp -d)" \
    && OS="$(uname | tr '[:upper:]' '[:lower:]')" \
    && ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" \
    && KREW="krew-${OS}_${ARCH}" \
    && curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"\
    && tar zxvf "${KREW}.tar.gz" \
    && ./"${KREW}" install krew \
    && echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bash_profile \
    && echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bashrc \
    && cd -

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME

RUN steampipe plugin install kubernetes \
    && steampipe plugin install azure
