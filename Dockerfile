FROM ubuntu:24.04

# Bump here. T3: version + sha256 of t3-<v>-linux-x64.tar.gz from the release's SHA256SUMS.
ARG T3_VERSION=0.0.45
ARG T3_SHA256=10505ae74bc6a43cfab0fde0bf06a0e0d6862f74030591be994a640d48a0d6bd
ARG CLAUDE_CODE_VERSION=2.1.287
ARG CODEX_VERSION=0.162.1
# (gh api repos/anomalyco/opencode/releases/tags/vX.Y.Z -q '.assets[]|select(.name=="opencode-linux-x64.tar.gz").digest')
ARG OPENCODE_VERSION=1.18.35
ARG OPENCODE_SHA256=c8f888b451f5494a18f858fffb0e0b68f4e4baa9c241761c5f206884f0fa640d

# Global npm installs go to /opt/npm, owned by the t3 user, so T3's "Update" button for
# Claude/Codex works without root (until the next redeploy restores the pinned versions).
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 PORT=8080 \
    NPM_CONFIG_PREFIX=/opt/npm PATH=/opt/npm/bin:$PATH \
    OPENCODE_DISABLE_AUTOUPDATE=1 DISABLE_AUTOUPDATER=1

# Toolbox the agents work with: git, gh, Node 22, Python 3 + uv, build tools, ripgrep.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg git openssh-client nginx-light sudo tmux \
      vim nano less htop ripgrep fd-find jq unzip zip tree procps locales qrencode tini \
      python3 python3-pip python3-venv build-essential libatomic1 \
  && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends nodejs gh \
  && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh \
  && npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" "@openai/codex@${CODEX_VERSION}" \
  && npm cache clean --force && claude --version && codex --version \
  && curl -fsSL -o /tmp/t3.tgz "https://github.com/pingdotgg/t3code/releases/download/v${T3_VERSION}/t3-${T3_VERSION}-linux-x64.tar.gz" \
  && echo "${T3_SHA256}  /tmp/t3.tgz" | sha256sum -c - \
  && mkdir -p /opt/t3 && tar xzf /tmp/t3.tgz -C /opt/t3 --strip-components=1 && rm /tmp/t3.tgz \
  && ln -s /opt/t3/t3 /usr/local/bin/t3 && t3 --version \
  && curl -fsSL -o /tmp/oc.tgz "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-x64.tar.gz" \
  && echo "${OPENCODE_SHA256}  /tmp/oc.tgz" | sha256sum -c - \
  && tar xzf /tmp/oc.tgz -C /usr/local/bin opencode && rm /tmp/oc.tgz && opencode --version \
  && ln -s /usr/bin/fdfind /usr/local/bin/fd \
  # nginx `auto` sizes from the host's cores on Railway, not the container's limit.
  && sed -i 's/^worker_processes .*/worker_processes 2;/' /etc/nginx/nginx.conf \
  && rm -f /etc/nginx/sites-enabled/default \
  # Agents run as a normal user (Claude Code refuses its skip-permissions mode as root),
  # with passwordless sudo so they can still apt-get what a repo needs.
  && userdel -r ubuntu \
  && useradd -m -u 1000 -s /bin/bash t3 \
  && chown -R t3:t3 /opt/npm \
  && echo 't3 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/t3 && chmod 440 /etc/sudoers.d/t3 \
  && echo 'export PATH="$HOME/.local/bin:/opt/npm/bin:$PATH"' > /etc/profile.d/local-bin.sh \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY railway-pair.mjs /opt/railway-pair.mjs
COPY entrypoint.sh /entrypoint.sh
COPY drop-file-cache /usr/local/bin/drop-file-cache

EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
