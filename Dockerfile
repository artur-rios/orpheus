# The docs site of Orpheus (the catalog's orpheus-docs, served at docs.artur-rios.tech/orpheus): the Hugo site in
# docs/site, built in a pinned Hugo image and served by static-web-server. It is the templates/site-hugo Dockerfile of
# yggdrasil, with the differences marked below. The repository has no other image, so this is the `Dockerfile` that
# yggdrasil's stacks/orpheus-docs.yml builds by default.
#
# The build arguments are the stack file's (templates/stacks/site.yml), which scripts/deploy.sh feeds:
#   PUBLIC_HOST, PUBLIC_PATH   the address the site is served at: Hugo's baseURL is https://<host><path>/ (just
#                    <path>/ when there is no host). The proxy does not strip the path, so the files are put under it
#                    too. The baseURL of docs/site/hugo.toml is only what `hugo server` uses: this overrides it.
#   HUGO_DIR         the Hugo site's directory. The stack file does not pass it, so the default is the site's own.
#   GIT_COMMIT, YGG_ENVIRONMENT   the commit and the environment this image is built for ({{ getenv
#                    "HUGO_GIT_COMMIT" }} and {{ getenv "HUGO_YGG_ENVIRONMENT" }} in a Hugo template: Hugo's getenv
#                    only allows names that start with HUGO_). The site does not read them today.
#
# Different from the template:
#   1. The theme (Docsy) is a Hugo module (docs/site/go.mod), not an npm package, so the image needs Go: the `go`
#      variant of the same Hugo release. Hugo fetches the module from proxy.golang.org (docs/site/hugo.toml) and
#      go.sum pins its hash. Nothing in the site reads the git history (no enableGitInfo), so .git is not in the
#      build context.
#   2. Docsy compiles its SCSS with Dart Sass, which Hugo looks up as `sass` on the PATH; the image has none. The
#      standalone release is downloaded, checked against the checksum GitHub publishes for it, and put on the PATH,
#      as the Docs workflow did. Docsy v0.18.0 needs the version below or newer.
#   3. Docsy's Bootstrap and Font Awesome are npm packages (docs/site/package-lock.json). The Hugo image has no Node,
#      so a pinned Node image installs them (`npm ci`) and the Hugo stage takes the node_modules directory.
#   4. The site renders CHANGELOG.md and CONTRIBUTING.md from the repository's root (docs/site/hugo.toml mounts them),
#      so those two files are part of the context, which .dockerignore otherwise reduces to the site.
ARG HUGO_DIR=docs/site

FROM node:24.22.1-alpine3.24@sha256:06d7adf3e0ef61a13f1d28682726366f97a15aa1888c934d3ecec86c33918b53 AS npm

ARG HUGO_DIR
WORKDIR /src/${HUGO_DIR}
COPY ${HUGO_DIR}/package.json ${HUGO_DIR}/package-lock.json ./
COPY ${HUGO_DIR}/packages/ packages/
RUN npm ci --no-audit --no-fund

FROM hugomods/hugo:debian-go-0.165.0@sha256:450b7b571d7d81c29e68c971bcf06e346607ab1e3c351967a74fa4dc3b041d28 AS build

# Renovate follows the version below (the comment under this one), but not the checksum: when it moves the version,
# copy the sha256 of dart-sass-<version>-linux-x64.tar.gz from the release page into the ADD by hand.
# renovate: datasource=github-releases depName=sass/dart-sass
ARG DART_SASS_VERSION=1.105.0
ADD --checksum=sha256:2620fa32fdc09411469539e3b678a31a4f164ed704aaee9f8f1ab664dbaa153b \
    https://github.com/sass/dart-sass/releases/download/${DART_SASS_VERSION}/dart-sass-${DART_SASS_VERSION}-linux-x64.tar.gz \
    /tmp/dart-sass.tar.gz
RUN tar -xzf /tmp/dart-sass.tar.gz --no-same-owner -C /opt && rm /tmp/dart-sass.tar.gz
ENV PATH="/opt/dart-sass:${PATH}"

ARG HUGO_DIR
WORKDIR /src
COPY . .
COPY --from=npm /src/${HUGO_DIR}/node_modules/ ${HUGO_DIR}/node_modules/

ARG PUBLIC_HOST=
ARG PUBLIC_PATH=
ARG GIT_COMMIT=
ARG YGG_ENVIRONMENT=
ENV HUGO_GIT_COMMIT=${GIT_COMMIT} \
    HUGO_YGG_ENVIRONMENT=${YGG_ENVIRONMENT}

RUN set -eu; \
    cd "$HUGO_DIR"; \
    if [ -n "$PUBLIC_HOST" ]; then base="https://$PUBLIC_HOST$PUBLIC_PATH/"; else base="$PUBLIC_PATH/"; fi; \
    hugo --environment production --minify --gc --baseURL "$base" --destination /out

FROM joseluisq/static-web-server:2.44.1@sha256:94618e3d17802265a21926217e6f9e7832b311b6fbf5933684001739fafed06a

# Declared again: an argument lives in the stage that declares it.
ARG PUBLIC_PATH=
ARG GIT_COMMIT=
ARG YGG_ENVIRONMENT=

# The server has no shell, so nothing is run here: the site is copied under its path, and /healthz is a file of
# its own at the root. Port 8080, a numeric non-root user.
COPY --from=build /out/ /public${PUBLIC_PATH}/
COPY <<EOF /public/healthz
ok
EOF

# Hugo writes 404.html at the site's root (under the path): an address the site does not have is a 404.
ENV SERVER_PORT=8080 \
    SERVER_ROOT=/public \
    SERVER_ERROR_PAGE_404=/public${PUBLIC_PATH}/404.html

LABEL org.opencontainers.image.revision="${GIT_COMMIT}" \
      yggdrasil.built-for="${YGG_ENVIRONMENT}"

USER 65532:65532
EXPOSE 8080
