# ldr2readlater
Livedoor Reader のピン情報を定期的に取得し、あとで読むサービス（Read it Later や Instapaper）に登録します。

なんとなくHeroku対応出来ました。
エラーとか発生したら死ぬような最低限の対処はしてる…つもり。

## 動かし方

### githubから取得
$ git clone git://github.com/Echos/ldr2readlater.git
$ cd ldr2readlater

### heroku コマンドのインストール（未実施の方）
```sh
$ gem install heroku       # rvmとかrbenvな環境の人用
# or
$ sudo gem install heroku  # 上記以外
```

### heroku上にアプリケーション作成
```sh
$ heroku apps:create --stack cedar

# Read it Laterの場合
$ heroku config:add \
  RIL_USER=[YOUR READ_IT_LATER USER_ID] \
  RIL_PASS=[YOUR READ_IT_LATER PASSWORD] \
  RIL_API_KEY=[YOUR READ_IT_LATER API_KEY] \
  LDR_USER=[YOUR LDR USER_ID] \
  LDR_PASS=[YOUR LDR PASS] \
  TIME=[Update interval TIME (min)]


# instapaperの場合
$ heroku config:add \
  INSTA_USER=[YOUR INSTAPAPER USER_ID] \
  INSTA_PASS=[YOUR INSTAPAPER PASSWORD] \
  LDR_USER=[YOUR LDR USER_ID] \
  LDR_PASS=[YOUR LDR PASS] \
  TIME=[Update interval TIME (min)]

※TIMEは設定しない場合、１０分間隔になります
```

### herokuへプッシュしてサービススタート
```sh
$ git push heroku master
$ heroku ps:scale web=0 clock=1
```

### ログみてちゃんと動いているか確認してください
```sh
$ heroku ps
$ heroku logs -t
```