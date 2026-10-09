FROM node:22-bookworm-slim AS build
WORKDIR /app
COPY server/package*.json ./
RUN npm ci
COPY server/tsconfig.json ./
COPY server/src ./src
COPY assets/config ./assets/config
RUN npm run build

FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY server/package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY --from=build /app/assets ./assets
COPY server/scripts ./scripts
RUN mkdir -p /data /backups && chown -R node:node /app /data /backups
USER node
EXPOSE 8787
CMD ["node","dist/src/main.js"]
