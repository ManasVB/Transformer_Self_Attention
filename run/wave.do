onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_top/dut/reset_n
add wave -noupdate /tb_top/dut/clk
add wave -noupdate /tb_top/dut/dut_valid
add wave -noupdate /tb_top/dut/dut_ready
add wave -noupdate -color Cyan -itemcolor Cyan /tb_top/dut/dut__tb__sram_input_write_enable
add wave -noupdate -color Cyan -itemcolor Cyan -radix decimal /tb_top/dut/dut__tb__sram_input_read_address
add wave -noupdate -color Cyan -itemcolor Cyan -radix hexadecimal /tb_top/dut/tb__dut__sram_input_read_data
add wave -noupdate -color Pink -itemcolor Pink /tb_top/dut/dut__tb__sram_weight_write_enable
add wave -noupdate -color Pink -itemcolor Pink /tb_top/dut/dut__tb__sram_weight_read_address
add wave -noupdate -color Pink -itemcolor Pink -radix hexadecimal /tb_top/dut/tb__dut__sram_weight_read_data
add wave -noupdate /tb_top/dut/dut__tb__sram_result_write_enable
add wave -noupdate -radix decimal /tb_top/dut/dut__tb__sram_result_write_address
add wave -noupdate -radix hexadecimal /tb_top/dut/dut__tb__sram_result_write_data
add wave -noupdate -radix unsigned /tb_top/dut/dut__tb__sram_result_read_address
add wave -noupdate -radix unsigned /tb_top/dut/tb__dut__sram_result_read_data
add wave -noupdate /tb_top/dut/dut__tb__sram_scratchpad_write_enable
add wave -noupdate -radix decimal /tb_top/dut/dut__tb__sram_scratchpad_write_address
add wave -noupdate -radix hexadecimal /tb_top/dut/dut__tb__sram_scratchpad_write_data
add wave -noupdate -radix unsigned /tb_top/dut/dut__tb__sram_scratchpad_read_address
add wave -noupdate -radix unsigned /tb_top/dut/tb__dut__sram_scratchpad_read_data
add wave -noupdate /tb_top/dut/current_state
add wave -noupdate /tb_top/dut/weight_matrix_dim
add wave -noupdate /tb_top/dut/input_col_itr
add wave -noupdate /tb_top/dut/weight_dim_itr
add wave -noupdate /tb_top/dut/input_row_itr
add wave -noupdate /tb_top/dut/z_col_itr
add wave -noupdate -radix unsigned /tb_top/dut/input_data_r
add wave -noupdate -radix unsigned /tb_top/dut/weight_data_r
add wave -noupdate -radix unsigned /tb_top/dut/accum_result
add wave -noupdate -radix unsigned /tb_top/dut/mac_result_z
add wave -noupdate /tb_top/dut/input_col_itr_sel
add wave -noupdate /tb_top/dut/input_row_itr_sel
add wave -noupdate /tb_top/dut/weight_dim_itr_sel
add wave -noupdate /tb_top/dut/compute_start
add wave -noupdate /tb_top/dut/result_write_en
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 317
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {2214 ns} {2273 ns}
