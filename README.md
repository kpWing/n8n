# 何
- n8nのセルフホスト版のDockerfileの管理repo



## ビルド・起動方法
```
docker build -t my-n8n .

docker run -d \
  --rm \
  -p 5678:5678 \
  --name n8n \
  -v ./n8n-data:/home/node/.n8n \
  --env-file .env \
  my-n8n
```
## フロー設定/Credentialの出力/インポート方法
- リカバリ手順(別のマシンで新たにコンテナ起動する場合とか)
  - ビルド、起動
  - アカウント作成
  - インポート
  - n8nの画面にアクセスして、対象のフローをpublishする

### エクスポート
- フローの設定や資格情報を追加修正したら都度エクスポートしてコミットしておく!!

```
#コンテナ内で実行
n8n export:workflow --all --output=/home/node/.n8n/workflows/get-and-summerize-news.json
n8n export:credentials --all --output=/home/node/.n8n/credentials/cred.json

#ホストで実行
cp n8n-data/workflows/get-and-summerize-news.json workflows/get-and-summerize-news.json
cp n8n-data/credentials/cred.json credentials/cred.json
#コミットしておく・・・

```

### インポート
```
#ホストで実行(エクスポート、コミットされてる前提)
mkdir n8n-data/workflows
n8n-data/credentials
cp workflows/get-and-summerize-news.json n8n-data/workflows/get-and-summerize-news.json
cp credentials/cred.json n8n-data/credentials/cred.json

#コンテナ内で実行
n8n import:workflow --input=/home/node/.n8n/workflows/get-and-summerize-news.json
n8n import:credentials --input=/home/node/.n8n/credentials/cred.json
```
