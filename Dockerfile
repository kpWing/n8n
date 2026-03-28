FROM n8nio/n8n:latest

WORKDIR /home/node

COPY workflows/get-and-summerize-news.json init/workflows/get-and-summerize-news.json
COPY credentials/cred.json init/credentials/cred.json

EXPOSE 5678
