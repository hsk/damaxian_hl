# DAMAXIAN MSX in hlang

[hlang](https://github.com/hsk/HLang)（Z80 向けの自作の言語）の作例です。同じゲームを、手書きのアセンブラ版・C（SDCC）版・hlang 版で比べられます。

## 原作と権利

- 原作は **CoBinee さんの [DAMAXIAN](https://github.com/CoBinee/damaxian-msx)**（MSX、全部アセンブラ）です。ゲームの内容、絵、背景、音楽（MML）の権利は CoBinee さんにあります。
- C 版 [hsk/damaxian_msx](https://github.com/hsk/damaxian_msx) は、hsk が原作を学習用に C（SDCC）へ書き直したものです。
- このリポジトリの hlang 版は、C 版をもとに hlang へ移したものです。`pattern.hl` と `bg.hl` は、C 版のデータ（原作の絵と背景）を写したものです。
- 原作にも C 版にもライセンスの表示がないので、このリポジトリにもライセンスは付けていません。非営利の学習用の作例として公開しています。**原作者の CoBinee さんから求めがあれば、すぐに取り下げます。**
- コンパイラの hlang は MIT ライセンスです（このリポジトリには含みません）。

比べる相手の 2 つは、git の submodule として [orig/](orig/) に参照してあります（中身はそれぞれのリポジトリにあります）。

```sh
git clone --recursive <このリポジトリ>        # または、clone 後に git submodule update --init
```

| ディレクトリ | 中身 |
| --- | --- |
| [orig/damaxian-msx](orig/damaxian-msx) | 原作のアセンブラ版（CoBinee/damaxian-msx） |
| [orig/damaxian_msx](orig/damaxian_msx) | C 版（hsk/damaxian_msx） |
| `.`（ここ） | hlang 版（下の 02-tuned と同じ） |
| [versions/](versions/) | hlang 版の 2 つの書き方（01-straight、02-tuned） |
| [tools/](tools/) | 測定のスクリプト（openMSX） |

## hlang 版について

C 版（`orig/damaxian_msx`）を、hlang に**ソースファイル単位で 1 対 1 に**移したものです。動きは、元の手書きアセンブラ版に合わせてあります（下の「アセンブラ版との一致」）。
ファイルの分け方、関数名、状態の遷移、固定小数点数、スプライトの並べ替え、MML の音楽ドライバまで、元と同じ作りにしてあります。

| 元（damaxian_msx/sources） | ここ | 内容 |
| --- | --- | --- |
| main.c | [main.hl](main.hl) | タイマ割り込み（H.TIMI）で 1 フレームずつ進める。main は STOP キーを待つだけ |
| System.c / System.h | [System.hl](System.hl) | キー入力、ビデオレジスタ、VRAM 転送、スプライト転送 |
| vdp.h | [vdp.hl](vdp.hl) | VDP のレジスタ番号 |
| Sound.c / Sound.h | [Sound.hl](Sound.hl) | 4 チャンネルの MML インタプリタ、PSG への書き込み、MML データ |
| Math.c / Math.h | [Math.hl](Math.hl) | 乱数、sin / cos の表、atan2 |
| App.c / App.h | [App.hl](App.hl) | モードの切り替え、スコアなどの共有変数 |
| Back.c / Back.h | [Back.hl](Back.hl) | 背景、スコア・倍率・タイマの表示、メッセージ |
| Title.c / Title.h | [Title.hl](Title.hl) | タイトル画面 |
| Game.c / Game.h | [Game.hl](Game.hl) | ゲーム画面の状態遷移、当たり判定、5 方向の撃ち返し |
| Ship.c / Ship.h | [Ship.hl](Ship.hl) | 自機 |
| Shot.c / Shot.h | [Shot.hl](Shot.hl) | ショット |
| Enemy.c / Enemy.h | [Enemy.hl](Enemy.hl) | 敵（イン、待機、ターン、アプローチ、爆発） |
| Bullet.c / Bullet.h | [Bullet.hl](Bullet.hl) | 敵の弾 |
| pattern.c | [pattern.hl](pattern.hl) | フォントとスプライトの絵（生成） |
| bg.c | [bg.hl](bg.hl) | 背景、ロゴ、メッセージ、敵の位置（生成） |
| bios.h, bdos.h, bios.inc, crt0.s | （`lib/msx.hl`、hlang の起動コード） | BIOS 呼び出しと起動 |

ヘッダ（.h）の定数や構造体は、対応する .hl の先頭にあります。`import` の関係は元の `makefile.depend` と同じです。

## 元との違い

- **初期化は最初の割り込みで行う。** 元は main が `SystemInitialize` などを呼んでから割り込みを仕掛けます。hlang は「割り込みから呼ぶ関数」と「main から呼ぶ関数」を分ける決まりなので、`APP_MODE_INIT` のとき、最初の割り込みの `AppUpdate` が呼びます（`flag` は割り込み処理中の印を残して初期化）。
- **asm で書かれていた部分は hlang で書き直した。** `SystemUpdateInput`、`SystemTransfer*`、`SystemUpdateSound`、`SystemGetAtan2` など。分岐の癖（チャンネル A の音の有無を周波数の下位と上位の比較で決める、チャンネル D が鳴っている間はチャンネル C を出さない、など）も写しています。
- **`sprite` は `sprites`。** `lib/msx.hl` に同じ名前の関数があるためです。
- **速くするために、動きを変えずに次の 4 か所を変えた**（01-straight → 02-tuned で約 8%。下の「速さ」）。
  - `request` の印を、転送したら下ろす（元は下ろさず、同じレジスタ値を毎フレーム VDP に書き直す）。
  - `SystemTransferVram` は、転送の欄を番地で歩き、空きにするのは `src` だけ。
  - 弾と敵のスプライトの位置は、ループの中で 4 ずつ進めて持ち歩く（元は 1 つずつ計算し直す）。`Bullet` の `sprite_offset` は使わなくなったが、元との対応のため残してある。
  - `BackMakeDigits` は `next(p)` で読み進める。サウンドは、待ち時間のカウントダウンを呼び出し側で済ませる。
- **割り込みの最後の `jp h_timiRoutine`（保存した元のフックへ飛ぶ）はしない。** 保存だけして、終了時に戻します。
- **VDP のポートは 0x98 / 0x99 の固定値。** 元は 0x0006 / 0x0007 から読みます。
- 文字列の MML は、1 バイトずつの `data` にしてあります（MML の文字列は各ブロックのコメントに残してあります）。

## 作り方、遊び方

hlang のリポジトリを隣に置いて（`../hlang`）ビルドしておきます。別の場所なら `make HLANG=...` で指定します。

```sh
make          # main.rom（14080 バイト。hlang v0.2.0）
make run      # openMSX で起動（MACHINE=... で機種を変える）
make assets   # pattern.hl と bg.hl を元の C から作り直す
```

カーソルキーの左右で動き、スペースで撃ちます。Esc で一時停止、STOP で終了です。

## 速さと大きさ（SDCC 版、アセンブラ版との比較）

比べた相手は 2 つです。どちらも openMSX（C-BIOS_MSX1）に読み込んで測りました。

- **SDCC 版**: `orig/damaxian_msx`（C）を SDCC 4.6.0 でビルド（`--opt-code-speed`。`System.c`、`Sound.c`、`Math.c` などはインラインアセンブラ入り）。
- **アセンブラ版**: [CoBinee/damaxian-msx](https://github.com/CoBinee/damaxian-msx)（オリジナル。全部アセンブラで、サウンドも含む）。SDCC 付属の `sdasz80` と `sdld` でビルド。

**hlang v0.2.0 での値**（`tools/handler-time.sh`。乱数の種 4 つ × 3000 フレーム。キーは処理の出口で押し替えるので、版が違っても同じプレイになる）:

| | 平均 | 95% | 1/60 秒超え |
| --- | --- | --- | --- |
| hlang 版（02-tuned、ここ） | **43,787T** | 57,250T | 2.4% |
| hlang 版（01-straight） | 47,222T | 60,390T | 6.2% |

アセンブラ版と SDCC 版は、まだこの測り方で測り直していません。下の表は、前の測り方（種 1 つ × 6000 フレーム、hlang は v0.1.0 のころ）の値です。前の測り方は、版によってプレイ内容が少しずれていたので、1〜2% の揺れを含みます。

物差しは、**タイマ割り込みの処理 1 回（= 1 ゲームフレーム）の所要時間**です（[tools/handler-time.sh](tools/handler-time.sh)）。左右に動いて連射する入力を 6000 フレーム入れます。1/60 秒は 59,659T で、これを超えると割り込みが重なって、ゲームが 30fps に落ちます。「CPU の待ち時間の割合」は、フレームが落ちると待ちが増えて負荷が軽く見えるので使いません。

| | 平均 | 95% | 最大 | 1/60 秒超え |
| --- | --- | --- | --- | --- |
| アセンブラ版 | **45,538T** | 57,481T | 82,611T | 3.0% |
| SDCC 版 | 69,448T | 96,145T | 184,162T | 74.2% |
| hlang 版（調整後。[versions/02-tuned](versions/02-tuned/) と同じ） | 66,409T | 91,807T | 130,790T | 68.2% |
| hlang 版（素直に写した版。[versions/01-straight](versions/01-straight/)） | 71,988T | 97,850T | 122,609T | 76.2% |

| | hlang 版 | SDCC 版 | アセンブラ版 |
| --- | --- | --- | --- |
| コード + 表 | 約 14.9KB（ROM は 15360 バイト） | 約 14.8KB | 約 13.4KB |
| RAM | 842 バイト | 979 バイト（スタック 256 を含む） | 998 バイト（同） |

- **hlang 版は SDCC 版よりわずかに速いが、アセンブラ版には 3 割以上届かない。** C から移した版（hlang も SDCC も）は、積極的に遊ぶと、敵の撃ち返しが増える場面で 1/60 秒に収まらず、ゲームが遅くなる。アセンブラ版は収まる。
- 書き方の調整（01 → 02）で縮んだのは約 8% で、残りはコンパイラの出すコードの質による。調べた結果と、コンパイラで直したい点は [compiler-todo.md](compiler-todo.md) にある。

## アセンブラ版との一致

動きの基準は、元の手書きアセンブラ版（[CoBinee/damaxian-msx](https://github.com/CoBinee/damaxian-msx)）です。`orig/damaxian_msx`（C 版）は、アセンブラ版を C に書き直したもので、動きが少し変わっている箇所があり、hlang 版はそこをアセンブラ版に合わせてあります。

C 版（SDCC）と違う箇所（hlang 版はアセンブラ版の動き）:

| 箇所 | C 版 | アセンブラ版（hlang 版） |
| --- | --- | --- |
| 敵の「イン」 | `count0 == 0` のとき `count0 -= 2`（待たずに動く） | `count0 != 0` の間は `count0 -= 2` で待ち、0 になってから動く |
| 敵の絵（種類 0 の色） | `0x0a` と `0x09` を交互 | 両方 `0x0a` |
| 弾が画面の外に出る判定 | `x > 0xc4 \|\| y > 0xc4` | `x >= 0xc4 \|\| y >= 0xc4` |
| 自機と弾の当たり判定 | 座標を `i8` にして差を取る（座標が 128 以上で外れる） | 符号なし 8 ビットの差の絶対値 |
| 撃ち返しを止める判定 | `a + 0x30` を丸めない | 8 ビットで丸める |
| タイトルの色アニメ | 式の評価順に任せる | 1 つ目の乱数で色、2 つ目で位置 |
| ターン → アプローチ、タイトル、ゲームの終わり | `phase` を戻さない | `phase = 0` に戻す（動きには影響しない） |

openMSX で、同じ乱数の種と同じ入力（45 フレームごとに左右、9 フレームに 1 回スペース）をアセンブラ版と hlang 版に与え、**12,500 フレーム（約 3 分半。タイトル、プレイ、タイムアップ、ゲームオーバー、ハイスコア更新の曲、タイトルへ戻るまで）を毎フレーム比べて、次がすべて一致**しました。

- スプライト表（32 枚）
- 敵 9 体と弾 18 個の状態（位置、角度、状態、カウント）
- モードと状態
- スコア、倍率、タイマ
- PSG の 14 レジスタ（サウンド）

測定は [tools/](tools/) と、保存した [versions/](versions/) にあります。
