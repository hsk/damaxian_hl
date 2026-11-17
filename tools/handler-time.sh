#!/bin/sh
# 使い方: tools/handler-time.sh [ディレクトリ]   そのディレクトリの main.hl（既定は damaxian_hl）をビルドして、
# 割り込み処理の 1 ゲームフレームあたりの時間（T ステート）を、左右に動いて連射する入力で測る。
# 乱数の種を変えて SEEDS 回（既定 4）、1 回 FRAMES フレーム（既定 3000）走らせ、全部まとめて数える。
# キーは処理の出口で次のフレームの分に押し替えるので、コードの速さが違ってもプレイ内容は同じになる。
# 重なって来た割り込みの BIOS の処理時間は、測定値から引いてある（handler-time.tcl）。
# 1/60 秒は 59659T。これを超えるとゲームが 30fps に落ちる。
# 要る物: openMSX、python3。ROM は C-BIOS_MSX1 で動かす。
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "${HLANG:-$HERE/../../hlang}" && pwd)          # HLang のリポジトリ（既定は隣の ../hlang）
DIR=$(cd "${1:-$HERE/..}" && pwd)
TMP=$(mktemp -d)
cd "$DIR" || exit 1
if [ -n "$BIN" ]; then
  # アセンブラ版や SDCC 版の BLOAD 形式のファイル（tools/bin-time.sh から）。番地は BCNT RND INP FLAG で渡す
  SDCC=1; CART=""
else
  export HLANG_LIB=$ROOT/lib
  HLC=$ROOT/_build/default/bin/hlc.exe
  $HLC main.hl >/dev/null || exit 1
  ASM=$($HLC main.hl --asm 2>&1)
  eq() { echo "$ASM" | sed -n "s/^$1: equ \(0x[0-9a-f]*\)/\1/p"; }
  SDCC=0; CART="-cart main.rom"
  BCNT=$(eq backCount); RND=$(eq random); INP=$(eq input); FLAG=$(eq flag)
fi
run() {
cat > "$TMP/run.tcl" <<EOT
set ::out $TMP/out$1.txt
set ::sdcc $SDCC
set ::bin "$BIN"
set ::bcnt $BCNT
set ::rnd $RND
set ::inp $INP
set ::flagaddr $FLAG
set ::seed $1
set ::to ${FRAMES:-3000}
source $HERE/handler-time.tcl
EOT
openmsx -machine C-BIOS_MSX1 $CART -script "$TMP/run.tcl" >/dev/null 2>&1
}
n=${SEEDS:-4}; i=0
while [ $i -lt $n ]; do run $i; i=$((i+1)); done
cat "$TMP"/out*.txt > "$TMP/out.txt"
python3 - "$TMP/out.txt" <<'PY'
import statistics, sys
d = [int(l.split()[1]) for l in open(sys.argv[1])]
s = sorted(d)
p = lambda q: s[int(len(s) * q)]
over = sum(1 for x in d if x > 59659)
print(f"平均 {statistics.mean(d):.0f}T  中央 {p(0.5)}  95% {p(0.95)}  最大 {max(d)}  1/60秒超え {100 * over / len(d):.1f}%")
PY
rm -rf "$TMP"
