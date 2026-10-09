FROM node:22-alpine

ENV NODE_ENV=production \
    NODE_NO_WARNINGS=1 \
    DATA_DIR=/data \
    PORT=3000

WORKDIR /app
COPY server.mjs ./
COPY public ./public

# Pre-create /data owned by node so a fresh named volume inherits the ownership.
RUN mkdir -p /data && chown node:node /data
USER node

EXPOSE 3000
CMD ["node", "server.mjs"]
