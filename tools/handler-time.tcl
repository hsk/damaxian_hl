# 割り込み処理（H.TIMI から呼ぶ関数）の所要時間を、ゲームフレームごとに記録する openMSX のスクリプト。tools/handler-time.sh から使う
set throttle off
set ::fc 0
set ::armed 0
set ::calls 0
set ::prev 0
set ::f [open $::out w]
proc keys {fc} {
  set k 0
  set ph [expr {($fc / 45) % 4}]
  if {$ph == 0} { set k [expr {$k | 0x10}] }
  if {$ph == 2} { set k [expr {$k | 0x80}] }
  if {($fc % 9) < 2} { set k [expr {$k | 0x01}] }
  return $k
}
# ハンドラの処理中に重なって来た割り込みは、BIOS の割り込み処理（0x38 から戻るまで）の時間を引く。
# 引かないと、遅いほど重なって、測定値が非線形に動く。
set ::acc 0
set ::isrbp ""
proc isr_in {} {
  if {!$::inside || $::isrbp ne ""} return
  set ::ti [machine_info time]
  set sp [reg SP]
  set ret [expr {[peek $sp] | ([peek [expr {$sp+1}]] << 8)}]
  set ::isrbp [debug set_bp $ret "\[reg SP\] == [expr {$sp + 2}]" isr_out]
}
proc isr_out {} {
  if {$::isrbp eq ""} return
  set ::acc [expr {$::acc + [machine_info time] - $::ti}]
  catch {debug remove_bp $::isrbp}
  set ::isrbp ""
}
# キーは割り込み処理の出口で、次のフレームの分に押し替える。入口で押し替えると、処理が 1/60 秒を超えて
# 割り込みが重なったとき、重なった割り込みの BIOS が新しいキーを早めに読み、プレイ内容が速さで変わる。
proc setkeys {fc} {
  set k [keys $fc]
  if {$k != $::prev} {
    if {$::prev != 0} { keymatrixup 8 $::prev }
    if {$k != 0} { keymatrixdown 8 $k }
    set ::prev $k
  }
}
proc leave {} {
  set dt [expr {[machine_info time] - $::t0 - $::acc}]
  puts $::f "$::fc [expr {int($dt * 3579545)}] $::nested"
  catch {debug remove_bp $::exitbp}
  setkeys [expr {$::fc + 1}]
  if {$::isrbp ne ""} { catch {debug remove_bp $::isrbp}; set ::isrbp "" }
  set ::inside 0
}
set ::inside 0
set ::nested 0
proc hook {} {
  incr ::calls
  if {$::armed == 0} {
    if {$::calls == 3} { keymatrixdown 8 0x01 }
    if {$::calls == 8} { keymatrixup 8 0x01 }
    if {[peek [expr {$::inp + 4}]] == 1} { poke $::rnd $::seed; poke $::bcnt 1; set ::armed 1; set ::prev 0; setkeys 1 }
    return
  }
  if {[peek $::flagaddr] & 1} { incr ::nested; return }   ;# 重なって来た割り込み（処理しない）
  # 前の処理が flag を下ろしてから戻るまでのすき間に来た割り込み。ゲームはこのフレームを処理するので、
  # 数えて、キーも押し替える（数えないと、どのフレームで起きるかが速さで変わり、プレイ内容がずれる）。
  # 時間は、前のフレームの値に混ざらないよう、割り込みの処理として引かれる（isr_in）。
  if {$::inside} {
    incr ::fc
    setkeys $::fc
    if {$::fc > $::to} { close $::f; exit }
    return
  }
  set ::inside 1
  incr ::fc
  set sp [reg SP]
  set ret [expr {[peek $sp] | ([peek [expr {$sp+1}]] << 8)}]
  set ::t0 [machine_info time]
  set ::acc 0
  set ::exitbp [debug set_bp $ret "\[reg SP\] == [expr {$sp + 2}]" leave]
  if {$::fc > $::to} { close $::f; exit }
}
proc arm {} {
  set e [expr {[peek 0xfda0] | ([peek 0xfda1] << 8)}]
  debug set_bp $e {} hook
}
if {$::sdcc} {
  after time 2 {
    set fd [open $::bin rb]; fconfigure $fd -translation binary
    seek $fd 7; set data [read $fd]; close $fd
    debug write_block memory 0x8400 $data
    reg PC 0x8400
  }
}
debug set_bp 0x38 {} isr_in
after time 7 arm
