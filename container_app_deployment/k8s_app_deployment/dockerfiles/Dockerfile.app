# Creative Energy App Server Container
FROM node:18-alpine

# Create user and directory structure matching VM environment
RUN addgroup -g 1000 rocky && \
    adduser -D -u 1000 -G rocky rocky && \
    mkdir -p /home/rocky

# Install git and other dependencies
RUN apk add --no-cache git curl dumb-init

# Set working directory to match VM structure
WORKDIR /home/rocky

# Create directory structure
RUN mkdir -p /home/rocky/ceweb/app-server && \
    mkdir -p /home/rocky/ceweb/files && \
    chown -R rocky:rocky /home/rocky

# Switch to rocky user for security
USER rocky

# Set working directory to app server location
WORKDIR /home/rocky/ceweb/app-server

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start the application (files will be populated by init container)
CMD ["node", "server.js"]