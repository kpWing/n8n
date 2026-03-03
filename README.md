# 何
- n8nのセルフホスト版のDockerfileの管理repo



## ビルド・起動方法
```
docker build -t my-n8n .

docker run -d \
  --rm \
  -p 5678:5678 \
  --name n8n \
  --user root \
  -v ./n8n-data:/home/node/.n8n \
  --env-file .env \
  my-n8n
```
## フロー設定/Credentialの出力/インポート方法
- ⭐️出力先のフォルダは考える
- ⭐️ECS化したい
- ⭐️リカバリ手順
  - アカウント作成(できればこれも省略したい)
  - ビルド、起動
  - アカウント作成
  - インポート

```
n8n export:workflow --all --output=/home/node/.n8n/workflows/get-and-summerize-news
n8n export:credentials --all --output=/home/node/.n8n/credentials/cred
```

```
n8n import:workflow --input=/home/node/.n8n/workflows/get-and-summerize-news
n8n import:credentials --input=/home/node/.n8n/credentials/cred
```
