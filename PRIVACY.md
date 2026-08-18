# プライバシーポリシー / Privacy Policy

**沖縄台風ナビ（Okinawa Typhoon Navi）**

最終更新日: 2026年8月18日

---

## 日本語

### 1. はじめに

本プライバシーポリシーは、iOS アプリ「沖縄台風ナビ」（以下「本アプリ」）が、ユーザーの情報をどのように扱うかについて説明するものです。

### 2. 収集する情報

本アプリは、以下の情報のみを取り扱います。

#### 2.1 位置情報

- **取得タイミング**: ユーザーが「現在地を追加」機能を明示的に実行した時、または「みんな」タブの投稿画面で「現在地から選ぶ」をタップした時のみ
- **保存場所**: 「現在地を追加」で保存した場所は、ユーザーの端末ローカル（iOS の UserDefaults）のみに保存されます
- **送信先**:
  - 「現在地を追加」: なし。外部サーバ・第三者サービスには一切送信しません
  - 「みんな」タブの「現在地から選ぶ」: 緯度・経度そのものは送信しません。現在地から自動判定した沖縄10区分の**エリア名のみ**を、投稿を確定した場合に限り送信します（詳細は §2.3）
- **目的**: 台風の現在位置と保存場所との距離・到達時間予測のため、および「みんな」タブでの投稿エリアの自動選択のため

#### 2.2 ユーザーが任意で登録した場所情報

- **取得内容**: 場所名、緯度・経度、通知優先度
- **保存場所**: ユーザーの端末ローカルのみ
- **送信先**: なし

#### 2.3 「みんな」タブへの投稿（エリア体感投稿）

- **投稿時に送信する情報**: 選択したエリア（沖縄10区分のいずれか）、体感レベル（5段階のうち1つ）、定型フレーズのID（20種類の固定文から選んだものの識別子）の3つのみです。**緯度・経度そのものや自由記述のテキストは送信しません**
- **送信先**: Apple の CloudKit の「パブリックデータベース」です。本アプリ独自のサーバーはありません
- **公開範囲**: パブリックデータベースに保存されるため、投稿は**誰でも読み取り可能**です。投稿には**iCloud へのサインインが必要**です（サインインしていなくても閲覧は可能です）
- **Apple が自動付与する識別子**: CloudKit の仕組みにより、投稿レコードには Apple が自動的にアプリ単位のユーザー識別子を関連付けます。本アプリはこの識別子を読み取ったり利用したりすることはありません
- **保持・削除**: 投稿はアプリを削除しても削除されません（詳しくは §6）。現時点では、投稿者自身が個々の投稿を削除する機能はアプリ内にありません

### 3. 収集しない情報

本アプリは、以下の情報を**一切収集しません**：

- 個人を特定できる情報（氏名、メールアドレス、電話番号など）
- アカウント・サインイン情報（本アプリ自体は独自のアカウント機能を持たず、氏名・メールアドレス・パスワード等を取得・保存しません。ただし「みんな」タブへの投稿には端末が iCloud にサインインしている必要があります。詳しくは §2.3 をご覧ください）
- 端末の広告識別子（IDFA）
- アプリの使用状況の分析データ（クラッシュレポート含む）
- 連絡先、写真、カレンダー、健康データ等の iOS の個人データ

### 4. 外部通信

本アプリは、以下の場合にのみインターネット通信を行います。

- **気象庁（Japan Meteorological Agency）からの台風情報取得（主データ源）**
  - 通信先: `https://www.jma.go.jp/bosai/typhoon/data/targetTc.json` および `https://www.jma.go.jp/bosai/typhoon/data/{eventId}/specifications.json`
  - 通信内容: 公開されている台風解析・予報 JSON の取得（HTTPS）
  - 送信する情報: なし（GET リクエストのみ）

- **米軍 JTWC（Joint Typhoon Warning Center）からの台風情報取得（取得失敗時の保険）**
  - 通信先: `https://www.metoc.navy.mil/jtwc/products/wpacprod.txt`
  - 通信内容: 公開されている台風警告テキストの取得（HTTPS）
  - 送信する情報: なし（GET リクエストのみ）

- **Apple CloudKit との通信（「みんな」タブの投稿・取得）**
  - 通信先: Apple の CloudKit（本アプリのパブリックデータベース）
  - 通信内容: エリア体感投稿の送信（書き込み）と、投稿一覧の取得（読み取り）
  - 送信する情報: 選択したエリア、体感レベル、定型フレーズID のみ（緯度・経度や氏名などは送信しません）
  - 上記2つとは異なり、これは**ユーザーが入力した内容を送信する書き込み通信**です。書き込み（投稿）には iCloud サインインが必要ですが、読み取り（閲覧）にはサインイン不要です。送信された投稿は誰でも読み取り可能な状態で保存されます

### 5. 第三者への提供

本アプリは、ユーザーの情報を第三者に提供することは**ありません**。

### 6. データの保持・削除

- **保存場所（§2.1・§2.2）**: 端末ローカルに保存されます。アプリを iOS から削除すれば、これらのデータは完全に削除されます。
- **「みんな」タブへの投稿（§2.3）**: Apple の CloudKit パブリックデータベースに保存されます。**アプリを端末から削除しても、投稿は削除されません**。また、現時点では投稿者自身が個々の投稿を削除する機能はアプリ内にありません。

### 7. 児童のプライバシー

本アプリは年齢制限 4+ で提供されますが、特定の年齢層を対象としたコンテンツや機能は持ちません。13 歳未満の児童から個人情報を意図的に収集することはありません。

### 8. 変更について

本プライバシーポリシーは、必要に応じて更新されることがあります。重要な変更がある場合は、アプリの新しいバージョンで通知します。

### 9. お問い合わせ

本プライバシーポリシーに関するご質問・ご意見は、以下までお願いします。

- メール: admin@takaapps.com
- GitHub: https://github.com/TAKAMONTA/typhoon-risk-navi/issues

---

## English

### 1. Introduction

This Privacy Policy describes how the iOS app "Okinawa Typhoon Navi" (the "App") handles user information.

### 2. Information We Collect

The App handles only the following information:

#### 2.1 Location Information

- **When collected**: Only when the user explicitly taps "Add Current Location," or taps "Use Current Location" on the post screen in the Mood tab
- **Storage**: Places saved via "Add Current Location" are stored locally on the user's device only (iOS UserDefaults)
- **Transmission**:
  - "Add Current Location": None. Never sent to external servers or third parties.
  - "Use Current Location" in the Mood tab: Your raw latitude/longitude is never sent. Only the **name of the Okinawa area** (one of 10 fixed areas) automatically determined from your location is sent, and only if you go on to submit a post (see §2.3).
- **Purpose**: To compute distance from a typhoon and arrival time predictions, and to auto-select the area for Mood tab posts

#### 2.2 User-Registered Location Data

- **Contents**: Location name, latitude/longitude, notification priority
- **Storage**: Locally on the user's device only
- **Transmission**: None

#### 2.3 Posting to the Mood Tab (Area Mood Posts)

- **Information sent when posting**: Only three values — the selected area (one of Okinawa's 10 areas), the mood level (one of 5 levels), and the ID of a fixed phrase (one of 20 preset phrases). **Raw latitude/longitude and free-text input are never sent.**
- **Destination**: Apple's CloudKit **public database**. The App has no server of its own.
- **Visibility**: Because posts are stored in a public database, they are **readable by anyone**. Posting **requires signing in to iCloud** (you can view the Mood tab without signing in, but you cannot post).
- **Identifier Apple attaches automatically**: CloudKit automatically attaches a per-app user record identifier to each post record. The App never reads or uses this identifier.
- **Retention and deletion**: Posts are not deleted when the App is deleted (see §6). There is currently no feature in the App for a user to delete their own individual posts.

### 3. Information We Do NOT Collect

The App does **not** collect:

- Personally identifiable information (name, email, phone number, etc.)
- Account or sign-in credentials (the App itself has no account system and does not collect your name, email address, or password. However, posting in the Mood tab requires your device to be signed in to iCloud — see §2.3)
- Advertising identifier (IDFA)
- App usage analytics or crash reports
- Contacts, photos, calendar, health data, or other personal iOS data

### 4. External Communications

The App performs network communication only in the following cases:

- **Retrieving typhoon information from JMA (Japan Meteorological Agency) — primary source**
  - Endpoints: `https://www.jma.go.jp/bosai/typhoon/data/targetTc.json` and `https://www.jma.go.jp/bosai/typhoon/data/{eventId}/specifications.json`
  - Content: Publicly available typhoon analysis/forecast JSON (HTTPS)
  - Information sent: None (GET request only)

- **Retrieving typhoon information from JTWC (Joint Typhoon Warning Center) — fallback when JMA fails**
  - Endpoint: `https://www.metoc.navy.mil/jtwc/products/wpacprod.txt`
  - Content: Publicly available typhoon warning text (HTTPS)
  - Information sent: None (GET request only)

- **Sending and retrieving Mood tab posts via Apple CloudKit**
  - Endpoint: Apple's CloudKit (this App's public database)
  - Content: Submitting area mood posts (write) and fetching the list of posts (read)
  - Information sent: Only the selected area, mood level, and phrase ID (no coordinates, name, or other personal information)
  - Unlike the two communications above, this is a **write that transmits content the user chose to submit**. Posting (write) requires iCloud sign-in; viewing (read) does not. Submitted posts are stored in a state that anyone can read.

### 5. Third-Party Sharing

The App **does not** share user information with third parties.

### 6. Data Retention and Deletion

- **Saved locations (§2.1, §2.2)**: Stored locally on the device. Deleting the App from iOS permanently deletes this data.
- **Mood tab posts (§2.3)**: Stored in Apple's CloudKit public database. **Deleting the App from your device does not delete your posts** — they remain in the database. There is currently no feature in the App for a user to delete an individual post.

### 7. Children's Privacy

The App is rated 4+, but does not target a specific age group. We do not knowingly collect personal information from children under 13.

### 8. Changes

This Privacy Policy may be updated as needed. Material changes will be communicated through new App versions.

### 9. Contact

For questions about this Privacy Policy:

- Email: admin@takaapps.com
- GitHub: https://github.com/TAKAMONTA/typhoon-risk-navi/issues
