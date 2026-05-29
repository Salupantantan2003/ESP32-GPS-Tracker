# ─── ESP32 GPS Tracker — Flutter Web Dockerfile ───────────────────────────────
# Build stage
FROM --platform=linux/amd64 ubuntu:22.04 AS build

RUN apt-get update && \
    apt-get install -y curl git unzip xz-utils zip libglu1-mesa && \
    rm -rf /var/lib/apt/lists/*

ENV FLUTTER_VERSION=3.22.3
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz \
    | tar xJ -C /opt && \
    /opt/flutter/bin/flutter doctor

ENV PATH="/opt/flutter/bin:${PATH}"

WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

# Serve stage
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
