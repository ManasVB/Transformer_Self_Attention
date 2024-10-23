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
reg [`SRAM_ADDR_RANGE]  result_write_address_w;

`define DATA_DIM_WIDTH (`SRAM_DATA_WIDTH >> 1)  // eg. if data range is 32 bits, only 16 bits represent row/col size

reg[`DATA_DIM_WIDTH-1 : 0]  input_rows;
reg[`DATA_DIM_WIDTH-1 : 0]  input_cols;
reg[`DATA_DIM_WIDTH-1 : 0]  weight_cols;
reg[`SRAM_DATA_RANGE] weight_dim;

reg[`DATA_DIM_WIDTH-1 : 0]  input_col_itr;
reg[`SRAM_DATA_RANGE] weight_dim_itr;
reg[`DATA_DIM_WIDTH-1 : 0]  k_itr;

// Read input and weight from SRAM in the next cycle after addr is read
reg[`SRAM_DATA_RANGE] input_r;
reg[`SRAM_DATA_RANGE] weight_r;
reg[`SRAM_DATA_RANGE] result_w;

// After input enable is set to 1 send the data read from SRAM to these registers for calculations
reg[`SRAM_DATA_RANGE] input;
reg[`SRAM_DATA_RANGE] weight;
reg[`SRAM_DATA_RANGE] accum;

// Local control variables
reg load_input_zero;
reg load_weight_zero;

reg input_rows_sel;
reg input_cols_sel;
reg weight_cols_sel;
reg weight_dim_sel;

reg input_col_itr_sel;
reg weight_dim_itr_sel;
reg k_itr_sel;

reg input_r_enable;
reg weight_r_enable;

reg input_enable;
reg weight_enable;
reg accum_select;

reg compute_complete;
reg set_dut_ready;
/*------------------------Control Logic---------------------------------*/
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

// Handshake logic
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    compute_complete <= 0;
  else
    compute_complete <= (set_dut_ready) ? 1'b1 : 1'b0;
end
assign dut_ready = compute_complete;

/*----------------FSM------------------*/
always @(*) begin

  set_dut_ready = 1'b0;

  load_input_zero = 1'b0;
  load_weight_zero = 1'b0;

  input_r_enable = 1'b0;
  weight_r_enable = 1'b0;

  input_rows_sel = 1'b1;
  input_cols_sel = 1'b1;
  weight_cols_sel = 1'b1;
  weight_dim_sel = 1'b1;

  input_col_itr_sel = 1'b1;
  weight_dim_itr_sel = 1'b1;
  k_itr_sel = 1'b0;

  input_enable = 1'b0;
  weight_enable = 1'b0;
  accum_select = 1'b0;  

  case (current_state)
    IDLE: begin
      if(dut_valid) begin
        next_state = S0;
      end
      else begin
        set_dut_ready = 1'b1;
        
        next_state = IDLE;
      end
    end
    S0: begin
      load_input_zero = 1'b1;
      load_weight_zero = 1'b1;

      next_state = S1;
    end
    S1: begin
      input_col_itr_sel = 1'b0;
      weight_dim_itr_sel = 1'b0;

      input_r_enable = 1'b1;
      weight_r_enable = 1'b1;

      next_state = S2;      
    end
    S2: begin
      input_col_itr_sel = ((input_col_itr+1) == input_cols);
      weight_dim_itr_sel = ((weight_dim_itr+1) == weight_dim);
      k_itr_sel = ((weight_dim_itr+1) == weight_dim);
      
      input_r_enable = 1'b1;
      weight_r_enable = 1'b1;

      input_rows_sel = 1'b0;
      input_cols_sel = 1'b0;
      weight_cols_sel = 1'b0;
      weight_dim_sel = 1'b0;

      next_state = S3;      
    end
    S3: begin
      input_col_itr_sel = ((input_col_itr+1) == input_cols);
      weight_dim_itr_sel = ((weight_dim_itr+1) == weight_dim);
      k_itr_sel = ((weight_dim_itr+1) == weight_dim);

      input_r_enable = 1'b1;
      weight_r_enable = 1'b1;

      next_state = (k_itr == input_rows) ? S4 : S3;        
    end
    S4: begin
      set_dut_ready = 1'b1;
      next_state = IDLE;
    end
    default: begin
      set_dut_ready = 1'b1;
      next_state = IDLE;
    end
  endcase
end

/*----------------Dimension Counts------------------*/
// No. of input rows
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    input_rows <= 0;
  else
    if(!input_rows_sel)
      input_rows <= input_r[16:31]; // No. of rows is in input0[31:16]
    else
      input_rows <= input_rows;
end

// No. of input cols
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    input_cols <= 0;
  else
    if(!input_cols_sel)
      input_cols <= input_r[15:0]; // No. of cols is in input0[15:0]
    else
      input_cols <= input_cols;
end

// No. of weight cols
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    weight_cols <= 0;
  else
    if(!weight_cols_sel)
      weight_cols <= weight_r[15:0]; // No. of cols is in weight0[15:0]
    else
      weight_cols <= weight_cols;
end

// Weight Matrix Dimension
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    weight_dim <= 0;
  else
    if(!weight_dim_sel)
      weight_dim <= (weight_r[15:0] * weight_r[31:16]); // Dim = weight0[15:0] * weight0[31:16]
    else
      weight_dim <= weight_dim;
end

/*----------------Iterators------------------*/
// Input column iterator
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    input_col_itr <= 0;
  else
    if(!input_col_itr_sel)
      input_col_itr <= 0;
    else
      input_col_itr <= input_col_itr + 1'b1;
end

// Weight Dimension iterator
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    weight_dim_itr <= 0;
  else
    if(!weight_dim_itr_sel)
      weight_dim_itr <= 0;
    else
      weight_dim_itr <= weight_dim_itr + 1'b1;
end

// K iterator: Whenever weight matrix is fully traversed K++
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    k_itr <= 0;
  else
    if(k_itr_sel)
      k_itr <= k_itr + 1'b1;
    else
      k_itr <= k_itr;
end

/*----------------Read Address------------------*/
// For input
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    input_read_address_r <= 0;
  else
    if(load_input_zero)
      input_read_address_r <= 0;
    else if(input_col_itr_sel)
      input_read_address_r <= (input_cols * k_itr) + 1'b1;
    else
      input_read_address_r <= input_read_address_r + 1'b1;
end
assign dut__tb__sram_input_read_address = input_read_address_r;

// For weight
always @(posedge clock) begin
  if(!reset_n)
    weight_read_address_r <= 0;
  else
    if(load_weight_zero)
      weight_read_address_r <= 0;
    else if(weight_dim_itr_sel)
      weight_read_address_r <= 1;
    else
      weight_read_address_r <= weight_read_address_r + 1'b1;
end
assign dut__tb__sram_weight_read_address = weight_read_address_r;

/*----------------Read SRAM Data------------------*/
// For input
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    input_r <= 0;
  else
    if(input_r_enable)
      input_r <= tb__dut__sram_input_read_data;
    else
      input_r <= input_r;
end

// For Weight
always @(posedge clock or negedge reset_n) begin
  if(!reset_n)
    weight_r <= 0;
  else
    if(weight_r_enable)
      weight_r <= tb__dut__sram_weight_read_data;
    else
      weight_r <= weight_r;
end

// /*----------------Math------------------*/
// // For input
// always @(posedge clock or negedge reset_n) begin
//   if(!reset_n)
//     input <= 0;
//   else
//     if(input_enable)
//       input <= input_r;
//     else
//       input <= input;
// end

// // For weight
// always @(posedge clock or negedge reset_n) begin
//   if(!reset_n)
//     weight <= 0;
//   else
//     if(weight_enable)
//       weight <= weight_r;
//     else
//       weight <= weight;
// end

// // For accumulator
// always @(posedge clock or negedge reset_n) begin
//   if(!reset_n)
//     accum <= 0;
//   else
//     if(accum_select)
//       accum <= 0;
//     else
//       accum <= accum;
// end

DW_fp_mac_inst 
  FP_MAC ( 
  .inst_a(tb__dut__sram_input_read_data),
  .inst_b(tb__dut__sram_weight_read_data),
  .inst_c(accum_result),
  .inst_rnd(inst_rnd),
  .z_inst(mac_result_z),
  .status_inst()
);

// /*----------------Write SRAM Data------------------*/
// // Address
// always @(posedge clock or negedge reset_n) begin
//   if(!reset_n)
//     result_write_address_w <= 0;
//   else
//     if(write_enable)
//       result_write_address_w <= result_write_address_w + 1'b1;
//     else
//       result_write_address_w <= result_write_address_w;
// end
// assign dut__tb__sram_result_write_address = result_write_address_w;

// // Data
// always @(posedge clock or negedge reset_n) begin
//   if(!reset_n)
//     result_w <= 0;
//   else
//     if(write_enable)
//       result_w <= mac_result_z;
//     else
//       result_w <= result_w;
// end
// assign dut__tb__sram_result_write_data = result_w;

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
