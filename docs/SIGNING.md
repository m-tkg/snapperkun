# コード署名と公証（Developer ID + notarization）

Snapperkun はアップデートで `.app` を入れ替えるため、**ビルドごとに署名が変わると
macOS のアクセシビリティ権限 (TCC) が無効化**されます（設定上は有効に見えるのに
ホットキーが効かず、権限を削除→再登録しないと動かない、という症状）。

これを防ぐには、**ビルドをまたいで同一の安定した署名アイデンティティ**で署名します。
Apple Developer Program の **Developer ID Application** 証明書で署名し、さらに
**notarization（公証）** すると、アクセシビリティ権限が保持されるうえ、Gatekeeper の
警告も出なくなります。

CI（GitHub Actions）が安定署名で署名・公証するよう、以下の Secrets を設定します。
シークレット未設定時は ad-hoc 署名（公証なし）にフォールバックします（その場合は権限が
保持されません）。

## 1. Developer ID Application 証明書を用意

1. Apple Developer Program に登録（年 $99）
2. Xcode > Settings > Accounts > 該当 Apple ID > **Manage Certificates** →
   `+` から **Developer ID Application** を作成
   （または developer.apple.com の Certificates から作成）
3. Keychain Access でその証明書（＋秘密鍵）を選び、右クリック **書き出す…** で
   `.p12`（パスワード付き）として保存

署名アイデンティティ名は次の形式です（`security find-identity -v -p codesigning` で確認可）:

```
Developer ID Application: Your Name (TEAMID1234)
```

## 2. app 用パスワード（公証用）を作成

[appleid.apple.com](https://appleid.apple.com) > サインインとセキュリティ >
**App 用パスワード** を生成する。

Team ID は developer.apple.com の Membership で確認できる 10 桁の英数字。

## 3. GitHub Secrets に登録

リポジトリの **Settings > Secrets and variables > Actions** に登録:

| Secret 名 | 値 |
|---|---|
| `SIGNING_CERTIFICATE_P12_BASE64` | `base64 -i DeveloperID.p12` の出力 |
| `SIGNING_CERTIFICATE_PASSWORD` | `.p12` のパスワード |
| `SIGNING_IDENTITY` | `Developer ID Application: Your Name (TEAMID1234)` |
| `NOTARY_APPLE_ID` | Apple ID（メールアドレス） |
| `NOTARY_PASSWORD` | 手順2の App 用パスワード |
| `NOTARY_TEAM_ID` | Team ID（10桁） |

```sh
base64 -i DeveloperID.p12 | pbcopy   # 1つ目の値をクリップボードへ
```

これらが揃うと、リリースワークフローは Developer ID で署名 → 公証 → staple します。
`SIGNING_*` のみで `NOTARY_*` が無い場合は署名のみ（公証スキップ＝Gatekeeper警告は残る）。
どちらも無ければ ad-hoc 署名にフォールバックします。

## 4. ローカルでの署名（任意・開発用）

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID1234)" bash Scripts/bundle.sh release
```

`SIGN_IDENTITY` 未指定なら ad-hoc 署名になります（Hardened Runtime / タイムスタンプは
アイデンティティ指定時のみ付与）。

## 5. 無料の代替（自己署名）

Apple Developer Program を使わない場合は、自己署名のコード署名証明書でも
**アクセシビリティ権限の保持だけ**は実現できます（Gatekeeper 警告は残る）。
`SIGNING_IDENTITY` に自己署名証明書名を設定し、`NOTARY_*` を未設定にすればよい
（キーチェーンアクセス > 証明書アシスタント > 証明書を作成 > 種類「コード署名」、
有効期間は長めに）。

## 6. 移行時の一回だけの再許可

ad-hoc 版から安定署名版に切り替わる初回だけ、署名が変わるため再許可が必要です:

1. システム設定 > プライバシーとセキュリティ > アクセシビリティ で
   古い Snapperkun のエントリを削除
2. 新しい版を起動して再度許可

以降、同じ証明書で署名されたアップデートでは権限が保持されます。
