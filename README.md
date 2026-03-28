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
n8n export:workflow --id WyY5WKPc4ob5MtrX --output=/home/node/init/workflows/get-and-summerize-news.json
n8n export:credentials --all --output=/home/node/init/credentials/cred.json

#コミットしておく・・・

```

### インポート
```
#コンテナ内で実行
n8n import:workflow --input=/home/node/init/workflows/get-and-summerize-news.json
n8n import:credentials --input=/home/node/init/credentials/cred.json
```

### EC2にのっける
- ローカル
```
# ターゲットを linux/amd64 に指定してビルド(armでもいいけどx86のほうが小さいサイズのEC2をたてられる)
docker build --platform linux/amd64 -t my-n8n-x86 .

# ただのローカル動作確認用
docker run -d \
  --rm \
  -p 5678:5678 \
  --name n8n \
  -v ./n8n-data:/home/node/.n8n \
  --env-file .env \
  my-n8n-x86

docker save my-n8n-x86 -o my-n8n-x86.tar

scp -r my-n8n-x86.tar n8n-work:/home/ec2-user/n8n/

```

- EC2(動作確認用に一旦public)
```
sudo yum update -y
sudo amazon-linux-extras install docker -y

# Docker をインストール
sudo dnf install -y docker

# Docker サービスを有効化・起動
sudo systemctl enable docker
sudo systemctl start docker

# ec2-user を docker グループに追加(sudo なしでdockerコマンド使えるように)
sudo usermod -aG docker ec2-user
# グループ追加後は再ログインが必要

docker load -i n8n/my-n8n-x86.tar 

mkdir -p ~/n8n-data
sudo chown -R 1000:1000 ~/n8n-data

docker run -d --name n8n \
  --rm \
  -p 5678:5678 \
  --name n8n \
  -v ./n8n-data:/home/node/.n8n \
#### TODO：.envをEC2に配置してコマンド化する
  my-n8n-x86


# 動作確認
http://{EC2のIPアドレス}:5678/

docker exec -it n8n sh
n8n import:workflow --input=/home/node/init/workflows/get-and-summerize-news.json
n8n import:credentials --input=/home/node/init/credentials/cred.json

# ここまでできたら一旦EC2からAMIを取る。起動中のEC2は止めて、AMIからprivateなEC2を作成し、Connect Endpointで接続できるようにしておく
```

- private EC2
```
# publicと同様にまずコンテナ起動してdocker execで入る
n8n list:workflow
n8n execute --id {↑で確認したID}
N8N_BLOCK_RESOURCES=true N8N_TASK_BROKER_PORT=5680 n8n execute --id WyY5WKPc4ob5MtrX

# ポートフォワーディングすればprivateEC2でもn8nのGUIを見ることができるのでpublicなEC2で動作確認する必要はなかった(NATゲートウェイの問題に気づけたので良かったとする)
ssh -L 5678:localhost:5678 n8n
http://localhost:5678/
```



### ECSはボツ
--- 

### ECSデプロイ
#### 課題
- 原因よくわかんないけど、コンテナ起動後にecs execでコンテナ入って、init/以下にあるエクスポートファイルからインポート叩いても、成功するのにサイト上は反映されない
  - 起動しっぱなしにしたくないのでそもそもインポートコマンドとかも起動時に自動でやってもらう必要あり
  - ローカルと違って現在ユーザがroot(ローカルはnode)になってるのが影響してるかも？
  - ボリュームマウントとか頑張れば解決できる？
#### 手順など
- 普通にビルドと実行
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

- ECRプライベートリポジトリ作る
  - URI控える　810477631786.dkr.ecr.ap-northeast-1.amazonaws.com/n8n-ecs
- ecrログイン
  ```
  aws sso login --profile sandbox-admin

  aws ecr get-login-password --region ap-northeast-1 --profile sandbox-admin \
  | docker login --username AWS --password-stdin 810477631786.dkr.ecr.ap-northeast-1.amazonaws.com

  docker tag my-n8n:latest \
  810477631786.dkr.ecr.ap-northeast-1.amazonaws.com/n8n-ecs:latest

  docker push 810477631786.dkr.ecr.ap-northeast-1.amazonaws.com/n8n-ecs:latest
  ```

- ECSクラスター作る
- ECSタスク定義作る
  - 環境変数は.envに記載したローカルのやつ＋以下
    ```
    N8N_HOST=0.0.0.0
    N8N_PORT=5678
    N8N_PROTOCOL=http
    N8N_SECURE_COOKIE=false
    ```
  - N8N_ENCRYPTION_KEYについてはSecretsManager経由がよさげ。
    - (WIP)値のタイプ：ValueFrom
    - 値：SecretsManagerでつくったARN
    - (WIP)IAMロール設定が必要かも
      - 
- クラスターから「タスク」起動
  - サブネットはpublic
  - セキュリティグループの設定必要(カスタムTCP/5678のインバウンド)
    - 作成後はタスクのENIに紐づいてるよ
- トラブル
  - SecretsManagerとれない
    ```
    タスクの停止時刻: 2026-03-28T03:54:01.125Z
    ResourceInitializationError: unable to pull secrets or registry auth: execution resource retrieval failed: unable to retrieve secret from asm: service call has been retried 1 time(s): failed to fetch secret arn:aws:secretsmanager:ap-northeast-1:810477631786:secret:N8N_ENCRYPTION_KEY-nAG4eC from secrets manager: operation error Secrets Manager: GetSecretValue, https response error StatusCode: 400, RequestID: d45b80b7-7a19-49eb-8fd2-44305bb5e5d7, api error AccessDeniedException: User: arn:aws:sts::810477631786:assumed-role/ecsTaskExecutionRole/668f97696c2f47f7ab6582a0b87413eb is not authorized to perform: secretsmanager:GetSecretValue on resource: arn:aws:secretsmanager:ap-northeast-1:810477631786:secret:N8N_ENCRYPTION_KEY-nAG4eC because no identity-based policy allows the secretsmanager:GetSecretValue action
    ```
    - ecsTaskExecutionRoleのIAMロールを編集して、SecretsManagerReadWriteを追加
  - なんかプラットフォームの指定ミスった
    - タスク定義のプラットフォームを「linux/arm64」にする
    ```
    タスクの停止時刻: 2026-03-28T04:01:44.070Z
    CannotPullContainerError: pull image manifest has been retried 7 time(s): image Manifest does not contain descriptor matching platform 'linux/amd64'
    ```
  - ブラウザアクセスしてもタイムアウト
    - タスク定義のポートマッピングミスってた -> コンテナポート5678
    - URLはhttp://{タスクのpublicIP}:5678/


- ECS Exec使いたい
- まねこんからじゃ有効にできないので、コマンドでタスク起動
    ```
    aws ecs run-task \
      --cluster n8n-ecs-cluster \
      --launch-type FARGATE \
      --task-definition n8n-task-definition:{リビジョン番号} \
      --enable-execute-command \
      --network-configuration "awsvpcConfiguration={
            subnets=[subnet-0f716dc9196c681e0],
            securityGroups=[sg-08c5b95c04c099ad2],
            assignPublicIp=ENABLED
        }" \
      --propagate-tags "TASK_DEFINITION" \
      --count 1 \
      --profile sandbox-admin
    ```

- タスク定義のロール設定
  - タスク実行ロールだけでなく、他スクロールにもecsTaskExecutionRoleを設定
  - さらにecsTaskExecutionRoleにポリシー追加しないとecs execできない(TargetNotConnectedExceptionが発生する)
      ```
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": [
              "ssmmessages:CreateControlChannel",
              "ssmmessages:CreateDataChannel",
              "ssmmessages:OpenControlChannel",
              "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
          }
        ]
      }
      ```
- ECS exec
    ```
    aws ecs execute-command \
        --cluster n8n-ecs-cluster \
        --task 33b1171fd6f1482d9131ed250fffa00c \
        --container n8n \
        --interactive \
        --command "/bin/sh" \
        --profile sandbox-admin

    ```
