# 保存した版

コンパイラの最適化の前後を比べられるように、2 つの版を残してあります。どちらも `main.hl` からビルドでき（`HLANG_LIB=../../../hlang/lib ../../../hlang/_build/default/bin/hlc.exe main.hl`）、アセンブラ版（[CoBinee/damaxian-msx](https://github.com/CoBinee/damaxian-msx)）と同じ動きをします。

| 版 | 内容 | 割り込み処理 1 回の平均（hlang v0.1.0 のころ、前の測り方） | 1/60 秒（59,659T）を超える |
| --- | --- | --- | --- |
| [01-straight](01-straight/) | 元の構造をそのまま写した版。書き方の工夫なし | 71,988T | 76.2% |
| [02-tuned](02-tuned/) | 01 の 6 か所を、コンパイラが出すコードに合わせて書き換えた版（`../` の本体と同じ） | 66,409T | 68.2% |
| （参考）SDCC 版 | C 版を SDCC でビルド | 69,448T | 74.2% |
| （参考）アセンブラ版 | 手書きの Z80 | 45,538T | 3.0% |

hlang v0.2.0 では、01-straight が 47,222T（1/60 秒超え 6.2%）、02-tuned が 43,787T（2.4%）です（今の測り方）。コンパイラの最適化で、01 と 02 の差は約 8% のまま、両方とも 3 割ほど速くなりました。経過は [../compiler-todo.md](../compiler-todo.md) にあります。

測り方は [../tools/handler-time.sh](../tools/handler-time.sh) です。`tools/handler-time.sh versions/01-straight` のように、ディレクトリを渡します。

## 01 → 02 の違い（コンパイラが賢くなれば、01 の書き方に戻せるもの）

`diff -ru 01-straight 02-tuned` で見られます。

| ファイル | 01（素直） | 02（調整） | 効いた量 |
| --- | --- | --- | --- |
| main.hl | `request` の印を下ろさず、毎フレーム転送を呼ぶ | 転送したら印を下ろす | 小（`SystemTransferVideoRegister` 毎フレーム 26 バイトの出力が消える） |
| System.hl `SystemTransferVram` | `videoTransfer[i].src` と添字で読む、全欄を 0 に戻す | 番地で歩き、`src` だけ 0 に戻す | 中（4.0% → 2.4%） |
| System.hl `SystemSetSprite` | 元の順 | 変数の寿命が短くなる順 | ほぼなし |
| Back.hl `BackMakeDigits` | `mem[src + i]` | `next(src)` で読み進める | 小 |
| Sound.hl | `SystemUpdateSoundChannel(c)` を 4 回呼ぶ | 待ちの数え下げだけ呼び出し側で | 小 |
| Bullet.hl、Enemy.hl | `BulletSpriteAt(ix)` を弾ごとに呼ぶ（`sprite_offset` を足して 72 で丸める） | ループの中で 4 ずつ進めて持ち歩く | 中（約 2.8 ポイント） |

合計で約 8% です。**アセンブラ版との差（約 31%）の大半は、書き方では縮まりません。** 残りは次の理由で、コンパイラ側の改善が要ります（[../compiler-todo.md](../compiler-todo.md)）。

- 構造体の 16 ビットの欄の足し算が、1 回 250T 前後かかる（アセンブラ版は 100T 前後）。弾の移動、敵の移動、当たり判定で、毎フレーム何十回も出る。
- `ix + n` の番地を、使うたびに作り直す。
- 一時変数を、メモリに何度も退避する。
- ループ変数や 4 番目の引数が、メモリに置かれる。
