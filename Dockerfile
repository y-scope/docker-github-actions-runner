# hadolint ignore=DL3007
FROM myoung34/github-runner-base:latest
LABEL maintainer="myoung34@my.apsu.edu"

ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
ENV ACTIONS_RUNNER_ACTION_ARCHIVE_CACHE=/home/runner/action-archive-cache
RUN mkdir -p /opt/hostedtoolcache /home/runner/action-archive-cache

ARG GH_RUNNER_VERSION="2.329.0"

ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /actions-runner
COPY install_actions.sh /actions-runner

RUN chmod +x /actions-runner/install_actions.sh \
  && /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm /actions-runner/install_actions.sh \
  && chown runner /_work /actions-runner /opt/hostedtoolcache

# Pre-cache commonly used GitHub Actions to avoid download timeouts
# Uses graceful error handling - build succeeds even if caching fails
COPY cache_github_actions.sh /actions-runner/
RUN chmod +x /actions-runner/cache_github_actions.sh \
  && /actions-runner/cache_github_actions.sh || echo "⚠ Action cache failed, continuing..." \
  && rm /actions-runner/cache_github_actions.sh

# Setup tool cache directory (tools cached on first use at runtime)
COPY cache_tools.sh /actions-runner/
RUN chmod +x /actions-runner/cache_tools.sh \
  && /actions-runner/cache_tools.sh || echo "⚠ Tool cache setup failed, continuing..." \
  && rm /actions-runner/cache_tools.sh

COPY token.sh entrypoint.sh app_token.sh /
RUN chmod +x /token.sh /entrypoint.sh /app_token.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]
