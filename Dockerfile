FROM node:18-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
ENV NODE_ENV=production
RUN npm run build
EXPOSE 3000
CMD ["node", "dist/index.js"]
