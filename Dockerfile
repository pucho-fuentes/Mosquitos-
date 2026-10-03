FROM node:20-alpine

WORKDIR /app

COPY server.js .
COPY graficas.html .
COPY datos.json* ./

EXPOSE 3000

CMD ["node", "server.js"]