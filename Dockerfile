FROM node:6.11.4-alpine
RUN apk add --update git
RUN mkdir -p /app

EXPOSE 4101
ENV DOCKERIZED=true
ENV PORT_EX=4101
ENV PORT_IN=4101

COPY app/package.json /app/
WORKDIR /app
RUN npm install --only-prod --ignore-scripts --silent --depth=0
RUN npm install --save git+https://github.com/luin/ioredis.git#v3.2.1

WORKDIR /app

COPY app /app

RUN chown -R node:node /app

USER node

CMD ["node", "--max_inlined_source_size=6000", "index.js"]
