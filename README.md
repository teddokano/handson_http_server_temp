# http_server_temp_handson

Zephyrファーストタッチ・ハンズオン用、out-of-treeアプリケーションフォルダです。
`zephyr/samples/`配下を一切変更せずに、このフォルダ単体でビルドできる構成にしています。
2回開催の入れ替え制のため、samples/以下を都度いじらずに済むよう独立させています。

## フォルダ構成

```
handson_http_server_temp/
├── CMakeLists.txt
├── prj.conf                 ← 元のhttp_serverサンプルのprj.confをベースに追記が必要
├── boards/
│   └── COPY_OVERLAY_HERE.txt ← ここにthermometerサンプルのboard overlayをコピー
└── src/
    └── main.c                ← 準備済み（/temperature エンドポイント追加版）
```

## 準備がまだの項目（Claude Codeでの調整時にやること）

1. **`prj.conf`を完成させる**
   `zephyr/samples/net/sockets/http_server/prj.conf`の内容をベースに、
   このフォルダの`prj.conf`に追記した`CONFIG_SENSOR=y`等とマージする

2. **`boards/`にoverlayをコピー**
   `zephyr/samples/sensor/thermometer/boards/<board>.overlay`を
   `boards/COPY_OVERLAY_HERE.txt`と置き換える形でコピーする
   (固定IP設定を別途overlayやprj.confで持っている場合はそれも統合)

3. **`src/`に不足している元サンプルのファイルをコピー**
   `zephyr/samples/net/sockets/http_server/src/`から以下をコピー:
   - `index.html.gz.inc`
   - `main.js.gz.inc`
   - `ws.h`
   （WebSocket機能を使わないなら`ws.c`は不要。`certificate.h`はTLS不使用のため不要）

4. **ビルド確認**
   ```
   west build -p auto -b <board_to_use> ~/handson_http_server_temp
   west flash
   ```

5. **動作確認**
   ブラウザで `http://<ボードの固定IP>/temperature` にアクセスし、
   気温がHTMLで表示されることを確認する

## 2回開催での運用イメージ

- 1回目開始前にビルド・書き込みを済ませ、10台とも同じイメージを書き込んでおく
- 1回目終了後、2回目までは基本的に**電源再投入のみ**で再利用できるはず
  (参加者側で状態を書き換える操作が無い構成のため)
- クラッシュ/ハング時のリセット手順だけ、リハーサル時に確認しておく
