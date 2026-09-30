FROM node:18-alpine

WORKDIR /app

# Pre-built static site — just serve it, no npm install/build needed
RUN npm install -g serve

COPY dist ./dist

EXPOSE 3000

CMD ["serve", "-s", "dist", "-l", "3000"]
