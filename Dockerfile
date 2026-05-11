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

# Copy hasil build ke nginx
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy nginx config (optional)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
