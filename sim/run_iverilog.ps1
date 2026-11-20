# Chay nhanh mot hoac tat ca 11 testbench bang Icarus Verilog + tuy chon mo GTKWave
# Cach dung:
#   .\run_iverilog.ps1                 (chay tat ca 11 testbench va sinh 11 file .vcd)
#   .\run_iverilog.ps1 tb_top          (chay tb_top va sinh tb_top.vcd)
#   .\run_iverilog.ps1 tb_top -Wave    (chay tb_top va mo luon cua so song GTKWave)

param(
    [string]$TargetTb = "",
    [switch]$Wave
)

$iverilog = if (Get-Command iverilog -ErrorAction SilentlyContinue) { "iverilog" } else { "C:\iverilog\bin\iverilog.exe" }
$vvp      = if (Get-Command vvp -ErrorAction SilentlyContinue)      { "vvp" }      else { "C:\iverilog\bin\vvp.exe" }
$gtkwave  = if (Get-Command gtkwave -ErrorAction SilentlyContinue)  { "gtkwave" }  else { "C:\iverilog\gtkwave\bin\gtkwave.exe" }

$rtl = @(
    "../rtl/gf_arithmetic/gf8_mul.v",
    "../rtl/gf_arithmetic/gf8_inv.v",
    "../rtl/rs_encoder/rs_encoder.v",
    "../rtl/demo/error_injector.v",
    "../rtl/rs_decoder/syndrome.v",
    "../rtl/rs_decoder/berlekamp_massey.v",
    "../rtl/rs_decoder/error_evaluator.v",
    "../rtl/rs_decoder/chien_search.v",
    "../rtl/rs_decoder/forney.v",
    "../rtl/rs_decoder/rs_decoder.v",
    "../rtl/uart/uart_tx.v",
    "../rtl/uart/uart_logger.v",
    "../rtl/board/hex_decoder.v",
    "../rtl/board/input_control.v",
    "../rtl/controller/rs_controller.v",
    "../rtl/board/top_de10_lite.v"
)

$allTbs = @(
    "tb_gf8_mul",
    "tb_gf8_inv",
    "tb_rs_encoder",
    "tb_syndrome",
    "tb_berlekamp_massey",
    "tb_error_evaluator",
    "tb_chien_search",
    "tb_forney",
    "tb_rs_decoder",
    "tb_uart_tx",
    "tb_top"
)

$tbs = if ($TargetTb -ne "") { @($TargetTb) } else { $allTbs }

foreach ($tb in $tbs) {
    $out = Join-Path $env:TEMP "$tb.vvp"
    & $iverilog -g2005 -I ../rtl/include -I ../tb -o $out @rtl "../tb/$tb.v"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[COMPILE ERROR] $tb" -ForegroundColor Red
        exit 1
    }
    & $vvp $out
}

if ($Wave -and $TargetTb -ne "") {
    $vcd = "$TargetTb.vcd"
    if (Test-Path $vcd) {
        Start-Process -FilePath $gtkwave -ArgumentList $vcd
    }
}
