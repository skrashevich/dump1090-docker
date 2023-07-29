# syntax=docker/dockerfile:1.6

ARG DEBIAN_FRONTEND=noninteractive
FROM debian:latest as builder
ARG DEBIAN_FRONTEND
# Prepare apt for buildkit cache
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
  && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' >/etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update && \
    apt install --no-install-recommends --no-install-suggests -y \
      build-essential \
      debhelper \
      fakeroot \
      git \
      libbladerf-dev \
      libhackrf-dev \
      liblimesuite-dev \
      libncurses-dev \
      librtlsdr-dev \
      pkg-config

WORKDIR /dump1090
ADD https://github.com/flightaware/dump1090.git /dump1090

RUN make -j$(nproc)

FROM debian:latest
ARG DEBIAN_FRONTEND
# Prepare apt for buildkit cache
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
  && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' >/etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update && \
    apt install --no-install-recommends --no-install-suggests -y \
      libbladerf2 \
      libhackrf0 \
      liblimesuite20.10-1 \
      libncurses6 \
      librtlsdr0 \
      nginx

COPY --link --from=builder /dump1090/dump1090 /usr/bin/dump1090
COPY --link --from=builder /dump1090/public_html/ /dump1090/public_html/
# fixes https://github.com/jeanralphaviles/dump1090-docker/issues/2
COPY <<-eot /dump1090/public_html/status.json
{"type": "dump1090-docker"}
eot
COPY <<-eot /dump1090/public_html/upintheair.json
{"rings": []}
eot

ADD --link nginx.conf mime.types run.sh /

EXPOSE 8080 30001 30002 30003 30004 30005 30104

ENTRYPOINT ["/run.sh"]
