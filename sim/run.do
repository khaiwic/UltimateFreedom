# =============================================================================
# run.do - Script khoi chay mo phong ModelSim / QuestaSim cho he thong Reed-Solomon
#
# Huong dan su dung trong ModelSim / QuestaSim GUI / Command-line:
#   1. Di chuyen den thu muc sim/:
#      cd <duong_dan_project>/sim
#   2. Chay macro script:
#      do run.do                (Chay testbench mac dinh: tb_rs_decoder)
#      do run.do tb_rs_encoder  (Chay testbench bo ma hoa)
#      do run.do tb_top         (Chay testbench cap board DE10-Lite)
# =============================================================================

# 1. Dong phien mo phong hien tai neu dang chay
quietly catch {quit -sim}

# 2. Xoa va khoi tao thu vien lam viec (work)
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# 3. Chon testbench can chay (mac dinh la tb_rs_decoder)
set TB "tb_rs_decoder"
if {[info exists 1]} {
    set TB $1
}
echo "========================================================================"
echo ">> SIM: Bat dau bien dich va mo phong voi Testbench: $TB"
echo "========================================================================"

# 4. Bien dich toan bo ma nguon RTL qua file list rtl_files.f
echo ">> SIM: Dang bien dich cac file RTL tu rtl_files.f ..."
vlog -work work +incdir+../rtl/include -f rtl_files.f

# 5. Bien dich testbench duoc chon
echo ">> SIM: Dang bien dich testbench: ../tb/$TB.v ..."
vlog -work work +incdir+../rtl/include +incdir+../tb ../tb/$TB.v

# 6. Khoi dong mo phong (vsim)
echo ">> SIM: Dang khoi tao phien mo phong vsim ..."
vsim -voptargs="+acc" -t 1ps work.$TB

# 7. Nap cau hinh dang song Waveform (wave.do) neu co
if {[file exists wave.do]} {
    echo ">> SIM: Dang nap cau hinh waveform tu wave.do ..."
    do wave.do
}

# 8. Chay mo phong
echo ">> SIM: Dang chay mo phong (run -all) ..."
run -all

# 9. Canh chinh khung hien thi song
catch {wave zoom full}
echo "========================================================================"
echo ">> SIM: Hoan tat mo phong cho $TB!"
echo "========================================================================"
