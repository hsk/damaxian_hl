#!/bin/sh
# 使い方: tools/bin-time.sh asm|sdcc
# 比べる相手の 2 つを、hlang 版と同じ測り方（tools/handler-time.sh）で測る。
#   asm:  原作のアセンブラ版。orig/damaxian-msx のビルド済み disk/DAMAXIAN.BIN をそのまま使う
#   sdcc: C 版。orig/damaxian_msx を一時ディレクトリに写し、今の SDCC で通るように直して（#0b... の # を外す）
#         make DAMAXIAN.com でビルドする（make だけだと、ビルドの後に openMSX が起動する）
# 要る物: openMSX、python3。sdcc は SDCC（4.6.0 で確かめた）。
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
case "$1" in
  asm)
    BIN=$REPO/orig/damaxian-msx/disk/DAMAXIAN.BIN
    # この BIN の中の番地（原作のソースをビルドしたときの map から）
    BCNT=0xd626 RND=0xd5fa INP=0xd507 FLAG=0xd505 ;;
  sdcc)
    T=$(mktemp -d)
    cp -R "$REPO/orig/damaxian_msx" "$T/c" && rm -rf "$T/c/.git"
    sed -i.bak 's/= #0b/= 0b/; s/c = #0x10;/c = 0x10;/' "$T/c/sources/Sound.c" "$T/c/sources/Back.c"
    (cd "$T/c" && make DAMAXIAN.com >/dev/null 2>&1) || { echo "SDCC のビルドに失敗"; exit 1; }
    BIN=$T/c/disk/DAMAXIAN.BIN
    noi() { sed -n "s/^DEF $1 \(0x[0-9A-Fa-f]*\)/\1/p" "$T/c/bin/DAMAXIAN.noi"; }
    INP=$(noi _input) FLAG=$(noi _flag)
    # random は static なので、SystemGetRandom の ld hl,#_random から読む
    RND=$(python3 - "$BIN" "$(noi _SystemGetRandom)" <<'PY'
import sys
b = open(sys.argv[1], "rb").read()
org = b[1] | (b[2] << 8)
i = int(sys.argv[2], 16) - org + 7
i = b.index(0x21, i)
print(hex(b[i + 1] | (b[i + 2] << 8)))
PY
)
    BCNT=0xefff ;;  # C 版には背景の数え（backCount）がないので、使われない番地へ書く
  *) echo "使い方: $0 asm|sdcc"; exit 1 ;;
esac
export BIN BCNT RND INP FLAG
sh "$HERE/handler-time.sh" "$REPO"
