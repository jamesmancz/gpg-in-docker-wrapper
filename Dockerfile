# Use a minimal, secure base image
FROM alpine:latest

# Add gnupg and its dependencies;
# pcsc-lite and pinentry are included as without them some interative prompts fail
RUN apk add --no-cache gnupg pcsc-lite pinentry

# Make entry point script available in container and executable
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create a non-root user to run GPG commands
RUN addgroup -g 1000 gpguser && \
    adduser -u 1000 -G gpguser -h /home/gpguser -s /bin/sh -D gpguser && \
    mkdir /work && \
    chown gpguser:gpguser /work

# Set the user and working directory
USER gpguser
WORKDIR /work

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]