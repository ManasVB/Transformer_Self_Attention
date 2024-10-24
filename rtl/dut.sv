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

// local variables declaration

reg compute_complete;
reg set_dut_ready;

reg enable_sram_address_r;
reg [`SRAM_ADDR_RANGE     ] input_address_r;
reg [`SRAM_ADDR_RANGE     ]  weight_address_r;

reg enable_sram_data_r;
reg input_read_diff;
reg weight_read_diff;
reg [`SRAM_DATA_RANGE] input_data_r;
reg [`SRAM_DATA_RANGE] weight_data_r;

reg dimension_size_select;
reg [`SRAM_DATA_RANGE] input_row_dim;
reg [`SRAM_DATA_RANGE] input_col_dim;
reg [`SRAM_DATA_RANGE] weight_col_dim;
reg [`SRAM_DATA_RANGE] weight_matrix_dim;

reg input_col_itr_sel;
reg [`SRAM_DATA_RANGE] input_col_itr;
reg weight_dim_itr_sel;
reg [`SRAM_DATA_RANGE] weight_dim_itr;
reg k_itr_sel;
reg [`SRAM_DATA_RANGE] k_itr;

/*----------------------Control Logic------------------------*/
`ifndef FSM_BIT_WIDTH
  `define FSM_BIT_WIDTH 4
`endif

typedef enum logic [`FSM_BIT_WIDTH-1:0] {
  IDLE  = `FSM_BIT_WIDTH'b0000,
  S0  = `FSM_BIT_WIDTH'b0001,
  S1  = `FSM_BIT_WIDTH'b0010,
  S2  = `FSM_BIT_WIDTH'b0011,
  S3  = `FSM_BIT_WIDTH'b0100,
  S4  = `FSM_BIT_WIDTH'b0101,
  S5  = `FSM_BIT_WIDTH'b0110
} e_states;

e_states current_state, next_state;

always @(posedge clk or negedge reset_n) begin
  if(!reset_n)
    current_state <= IDLE;
  else
    current_state <= next_state;
end

// Handshake logic
always @(posedge clk or negedge reset_n) begin
  if(!reset_n)
    compute_complete <= 0;
  else
    compute_complete <= (set_dut_ready) ? 1'b1 : 1'b0;
end
assign dut_ready = compute_complete;

// Set write enable for input and weight to zero
assign dut__tb__sram_input_write_enable = 1'b0;
assign dut__tb__sram_weight_write_enable = 1'b0;

/*----------------------FSM------------------------*/
always @(*) begin

  set_dut_ready = 1'b0;
  enable_sram_address_r = 1'b0;
  enable_sram_data_r = 1'b0;
  dimension_size_select = 1'b0;
  input_col_itr_sel = 1'b0;
  weight_dim_itr_sel = 1'b0;
  // input_read_diff = 1'b0;
  // weight_read_diff = 1'b0;

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
      enable_sram_address_r = 1'b1;
      next_state = S1;
    end

    S1: begin
      input_col_itr_sel = 1'b1;
      weight_dim_itr_sel = 1'b1;

      next_state = S2;
    end

    S2: begin
      enable_sram_data_r = 1'b1;
      dimension_size_select = 1'b1;
      
      next_state = S3;
    end

    S3: begin
      enable_sram_data_r = 1'b1;
      input_col_itr_sel = ((input_col_itr+1) == input_col_dim);
      weight_dim_itr_sel = ((weight_dim_itr+1) == weight_matrix_dim);

      // input_read_diff = ((input_col_itr + 1) == input_col_dim);
      // weight_read_diff = ((weight_dim_itr + 1) == weight_matrix_dim);

      k_itr_sel = ((weight_dim_itr + 2) == (weight_matrix_dim-1));

      next_state = ((k_itr) == input_row_dim) ? S4: S3;

      // $display("input row dim %x", input_row_dim);
      // $display("input col dim %x", input_col_dim);
      // $display("weight col dim %x", weight_col_dim);
      // $display("weight matrix dim %x", weight_matrix_dim);

      // $display("data %x",input_data_r);

      // $display("data %x",input_col_itr);

      // next_state = S4;
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

/*----------------------Read SRAM Address------------------------*/
always @(posedge clk or negedge reset_n) begin
  if(!reset_n || compute_complete)
    input_address_r <= 0;
  else begin
    if(enable_sram_address_r)
      input_address_r <= 0;
    else if(input_col_itr_sel)
      input_address_r <= (input_col_dim * k_itr) + 1'b1;
    else
      input_address_r <= input_address_r + 1'b1;
  end
end
assign dut__tb__sram_input_read_address = input_address_r;

always @(posedge clk or negedge reset_n) begin
  if(!reset_n || compute_complete)
    weight_address_r <= 0;
  else begin
    if(enable_sram_address_r )
      weight_address_r <= 0;
    else if(weight_dim_itr_sel)
      weight_address_r <= 1;
    else
      weight_address_r <= weight_address_r + 1'b1;
  end
end
assign dut__tb__sram_weight_read_address = weight_address_r;

/*----------------------Read SRAM Data------------------------*/
always @(posedge clk or negedge reset_n) begin
  if(!reset_n || compute_complete)
    input_data_r <= 0;
  else begin
    if(enable_sram_data_r)
      input_data_r <= tb__dut__sram_input_read_data;
    else
      input_data_r <= input_data_r;
  end
end

always @(posedge clk or negedge reset_n) begin
  if(!reset_n || compute_complete)
    weight_data_r <= 0;
  else begin
    if(enable_sram_data_r)
      weight_data_r <= tb__dut__sram_weight_read_data;
    else
      weight_data_r <= weight_data_r;
  end
end

/*----------------------Dimension Count------------------------*/
always @(posedge clk or negedge reset_n) begin
  if(!reset_n || compute_complete) begin
    input_row_dim <= 0;
    input_col_dim <= 0;
    weight_col_dim <= 0;
    weight_matrix_dim <= 0;
  end
  else begin
    if(dimension_size_select) begin
      input_row_dim <= tb__dut__sram_input_read_data[31:16];
      input_col_dim <= tb__dut__sram_input_read_data[15:0];
      weight_col_dim <= tb__dut__sram_weight_read_data[15:0];
      weight_matrix_dim <= tb__dut__sram_weight_read_data[15:0] * tb__dut__sram_weight_read_data[31:16];
    end
    else begin
      input_row_dim <= input_row_dim;
      input_col_dim <= input_col_dim;
      weight_col_dim <= weight_col_dim;
      weight_matrix_dim <= weight_matrix_dim;
    end
  end
end

/*----------------------Iterators------------------------*/
always @(posedge clk or negedge reset_n) begin
  if(!reset_n || compute_complete)
    input_col_itr <= 0;
  else
    if(input_col_itr_sel)
      input_col_itr <=0;
    else
      input_col_itr <= input_col_itr + 1'b1;
end

always @(posedge clk or negedge reset_n) begin
  if(!reset_n || compute_complete)
    weight_dim_itr <= 0;
  else
    if(weight_dim_itr_sel)
      weight_dim_itr <=0;
    else
      weight_dim_itr <= weight_dim_itr + 1'b1;
end

always @(posedge clk or negedge reset_n) begin
  if(!reset_n || compute_complete)
    k_itr <= 0;
  else
    if(k_itr_sel)
      k_itr <= k_itr + 1'b1;
    else
      k_itr <= k_itr;
end

/*----------------------MATH------------------------*/
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
