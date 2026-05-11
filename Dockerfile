# Stage 1: Build Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copy pubspec dan install dependencies
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy seluruh source code
COPY . .

# Build Flutter web
RUN flutter build web --release

# Stage 2: Serve dengan nginx
FROM nginx:alpine

# Install envsubst untuk ganti variable
RUN apk add --no-cache gettext

# Copy hasil build ke nginx
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy nginx config template
COPY nginx.conf /etc/nginx/conf.d/default.conf.template

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
