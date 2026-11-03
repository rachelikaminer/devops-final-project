# Official Nginx image that runs as a non-root user (UID 101) on port 8080
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Defaults for local runs - Cloud Run overrides PORT, and the deploy sets BACKEND_URL
ENV PORT=8080 \
    BACKEND_URL=http://backend:5000

# Files in /etc/nginx/templates are processed by envsubst at container startup
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 8080