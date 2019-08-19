# tbb/Dockerfile

FROM ubuntu:latest AS build
ARG BUILD_DATE
ARG VCS_REF
ARG VCS_URL
LABEL \
  org.label-schema.schema-version="1.0" \
  org.label-schema.build-date="${BUILD_DATE}" \
  org.label-schema.vcs-ref="${VCS_REF}" \
  org.label-schema.vcs-url="${VCS_URL}"
ENV DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
RUN set -euvx \
    && echo \
    && echo "make this container behave like a chroot" \
    && dpkg-divert --local --rename /usr/bin/ischroot \
    && ln -vsf /bin/true /usr/bin/ischroot \
    && echo \
    && echo "apt-get update, install" \
    && apt-get -y update \
    && apt-get -y --no-install-recommends install \
    build-essential \
    debhelper \
    devscripts \
    dh-make \
    dpkg-dev \
    ed \
    equivs \
    git \
    gnupg2 \
    liblockfile-simple-perl \
    libwww-perl \
    && true
ARG BUILD_CODE="default-build-code"
WORKDIR /tmp/${BUILD_CODE}/tbb
COPY . .
RUN set -euvx \
    && export PACKAGE="$(awk '/^Source:/{print $NF}' debian/control)" \
    && echo "PACKAGE: ${PACKAGE}" \
    && export GIT_DESCRIBE="$(git describe --long --always --tags --dirty | sed 's/[^[:alnum:]+-]/~/g')" \
    && echo "GIT_DESCRIBE: ${GIT_DESCRIBE}" \
    && git archive -o "../${PACKAGE}_${GIT_DESCRIBE}.orig.tar" HEAD \
    && xz -v "../${PACKAGE}_${GIT_DESCRIBE}.orig.tar" \
    && export ISSUE_NET="$(tr -dc '[:alnum:]' </etc/issue.net | tr '[:upper:]' '[:lower:]')" \
    && echo "ISSUE_NET: ${ISSUE_NET}" \
    && rm -vf debian/changelog \
    && dch --create --controlmaint --package "${PACKAGE}" --newversion "${GIT_DESCRIBE}-${ISSUE_NET}" "automated build" \
    && cat debian/changelog \
    && DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -j$(nproc) -sa -us -uc --source-option='-i.*' \
    && mkdir -vp out \
    && find .. -maxdepth 1 -type f -exec cp -v {} out \; \
    && (cd out && dpkg-scanpackages . >Packages && dpkg-scanpackages . >Sources) \
    && echo "done"

FROM ubuntu:latest AS deploy
ARG BUILD_CODE="default-build-code"
WORKDIR /tmp/${BUILD_CODE}/tbb/out
ARG BUILD_CODE="default-build-code"
COPY --from=build /tmp/${BUILD_CODE}/tbb/out/* ./
RUN set -euvx \
    && echo "deb     [trusted=yes] file://${PWD} ./" >>/etc/apt/sources.list.d/tbb.list \
    && echo "deb-src [trusted=yes] file://${PWD} ./" >>/etc/apt/sources.list.d/tbb.list \
    && apt-get update -y \
    && apt-get -y install libtbb-dev \
    && true
