//---------------------------------------------------------------------------
// DUT - Mini project 
//---------------------------------------------------------------------------
`include "common.vh"

module MyDesign(
//---------------------------------------------------------------------------
//System signals
  input wire reset_n                      ,  
  input wire clk                          ,

//---------------------------------------------------------------------------
//Control signals
  input wire dut_valid                    , 
  output wire dut_ready                   ,

//---------------------------------------------------------------------------
//input SRAM interface
  output wire                           dut__tb__sram_input_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_input_write_address ,
  output wire [`SRAM_DATA_RANGE     ]   dut__tb__sram_input_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_input_read_address  , 
  input  wire [`SRAM_DATA_RANGE     ]   tb__dut__sram_input_read_data     ,     

//weight SRAM interface
  output wire                           dut__tb__sram_weight_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_write_address ,
  output wire [`SRAM_DATA_RANGE     ]   dut__tb__sram_weight_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_read_address  , 
  input  wire [`SRAM_DATA_RANGE     ]   tb__dut__sram_weight_read_data     ,     

//result SRAM interface
  output wire                           dut__tb__sram_result_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_write_address ,
  output wire [`SRAM_DATA_RANGE     ]   dut__tb__sram_result_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_read_address  , 
  input  wire [`SRAM_DATA_RANGE     ]   tb__dut__sram_result_read_data          

);

// SRAM interface
reg [`SRAM_ADDR_RANGE]  input_read_address_r;
reg [`SRAM_ADDR_RANGE]  weight_read_address_r;

`define DATA_DIM_WIDTH (`SRAM_DATA_WIDTH >> 1)  // eg. if data range is 32 bits, only 16 bits represent row/col size

reg[`DATA_DIM_WIDTH-1 : 0]  input_rows;
reg[`DATA_DIM_WIDTH-1 : 0]  input_cols;
reg[`DATA_DIM_WIDTH-1 : 0]  weight_cols;
reg[`SRAM_DATA_RANGE] weight_dim;

reg[`DATA_DIM_WIDTH-1 : 0]  input_col_itr;
reg[`SRAM_DATA_RANGE] weight_dim_itr;
reg[`DATA_DIM_WIDTH-1 : 0]  k_itr;

// Local control variables
reg load_input_zero;
reg load_weight_zero;

reg input_rows_sel;
reg input_cols_sel;
reg weight_cols_sel;
reg weight_dim_sel;

wire input_col_itr_sel;
wire weight_dim_itr_sel;
wire k_itr_sel;

//---------------------------------------------------------------------------
//FSM registers for q_input_state

`ifndef FSM_BIT_WIDTH
  `define FSM_BIT_WIDTH 4
`endif

typedef enum logic [`FSM_BIT_WIDTH-1:0] {
  IDLE = `FSM_BIT_WIDTH'b0000,
  S0 = `FSM_BIT_WIDTH'b0001,
  S1 = `FSM_BIT_WIDTH'b0011,
  S3 = `FSM_BIT_WIDTH'b0100,
  S4 = `FSM_BIT_WIDTH'b0101,
  S5 = `FSM_BIT_WIDTH'b0110,
} e_states;

e_states current_state, next_state;

// Control Path
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    current_state <= IDLE;
  else
    current_state <= next_state;
end

/*----------------Dimension Counts------------------*/
// No. of input rows
always @(posedge clock) begin
  if(!input_rows_sel)
    input_rows <= tb__dut__sram_input_read_data[16:31]; // No. of rows is in input0[31:16]
  else
    input_rows <= input_rows;
end

// No. of input cols
always @(posedge clock) begin
  if(!input_cols_sel)
    input_cols <= tb__dut__sram_input_read_data[15:0]; // No. of cols is in input0[15:0]
  else
    input_cols <= input_cols;
end

// No. of weight cols
always @(posedge clock) begin
  if(!weight_cols_sel)
    weight_cols <= tb__dut__sram_weight_read_data[15:0]; // No. of cols is in weight0[15:0]
  else
    weight_cols <= weight_cols;
end

// Weight Matrix Dimension
always @(posedge clock) begin
  if(!weight_dim_sel)
    weight_dim <= (tb__dut__sram_weight_read_data[15:0] * tb__dut__sram_weight_read_data[31:16]); // Dim = weight0[15:0] * weight0[31:16]
  else
    weight_dim <= weight_dim;
end

/*----------------Iterators------------------*/
// Input column iterator
always @(posedge clock) begin
  if(!input_col_itr_sel)
    input_col_itr <= 0;
  else
    input_col_itr <= input_col_itr + 1'b1;
end
assign input_col_itr_sel = ((input_col_itr+1) == input_cols);

// Weight Dimension iterator
always @(posedge clock) begin
  if(!weight_dim_itr_sel)
    weight_dim_itr <= 0;
  else
    weight_dim_itr <= weight_dim_itr + 1'b1;
end
assign weight_dim_itr_sel = ((weight_dim_itr+1) == weight_dim);

// K iterator: Whenever weight matrix is fully traversed K++
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    k_itr <= 0;

  if(k_itr_sel)
    k_itr <= k_itr + 1'b1;
  else
    k_itr <= k_itr;
end
assign k_itr_sel = ((weight_dim_itr+1) == weight_dim);

/*----------------Matrices------------------*/
// For input matrix
always @(posedge clock) begin
  if(load_input_zero)
    input_read_address_r <= 0;
  else if()

end

assign dut__tb__sram_input_read_address = input_read_address_r;

// For weight matrix
always @(posedge clock) begin
  if(load_weight_zero)
    weight_read_address_r <= 0;
  else if()

end

assign dut__tb__sram_weight_read_address = weight_read_address_r;

DW_fp_mac_inst 
  FP_MAC ( 
  .inst_a(tb__dut__sram_input_read_data),
  .inst_b(tb__dut__sram_weight_read_data),
  .inst_c(accum_result),
  .inst_rnd(inst_rnd),
  .z_inst(mac_result_z),
  .status_inst()
);

endmodule

module DW_fp_mac_inst #(
  parameter inst_sig_width = 23,
  parameter inst_exp_width = 8,
  parameter inst_ieee_compliance = 0 // These need to be fixed to decrease error
) ( 
  input wire [inst_sig_width+inst_exp_width : 0] inst_a,
  input wire [inst_sig_width+inst_exp_width : 0] inst_b,
  input wire [inst_sig_width+inst_exp_width : 0] inst_c,
  input wire [2 : 0] inst_rnd,
  output wire [inst_sig_width+inst_exp_width : 0] z_inst,
  output wire [7 : 0] status_inst
);

  // Instance of DW_fp_mac
  DW_fp_mac #(inst_sig_width, inst_exp_width, inst_ieee_compliance) U1 (
    .a(inst_a),
    .b(inst_b),
    .c(inst_c),
    .rnd(inst_rnd),
    .z(z_inst),
    .status(status_inst) 
  );

endmodule: DW_fp_mac_inst