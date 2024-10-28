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

/*----------------------Local Variables Declaration------------------------*/

// Two flags to for handshake logic
reg compute_complete;
reg set_dut_ready;

reg enable_sram_address_r;
reg [`SRAM_ADDR_RANGE     ] input_address_r;
reg [`SRAM_ADDR_RANGE     ]  weight_address_r;
reg [`SRAM_ADDR_RANGE     ]  result_address_w;

reg enable_sram_data_r;
reg [`SRAM_DATA_RANGE] input_data_r;
reg [`SRAM_DATA_RANGE] weight_data_r;

reg dimension_size_select;  // Flag to load dimensions of both arrays in the below variables
reg [`SRAM_DATA_RANGE] input_row_dim;
reg [`SRAM_DATA_RANGE] input_col_dim;
reg [`SRAM_DATA_RANGE] weight_col_dim;
reg [`SRAM_DATA_RANGE] weight_matrix_dim;

reg input_col_itr_sel;
reg [`SRAM_DATA_RANGE] input_col_itr; // Traverse column elements of a single row of input matrix 
reg weight_dim_itr_sel;
reg [`SRAM_DATA_RANGE] weight_dim_itr;  // Traverse the entire weight matrix 
reg k_itr_sel;
reg [`SRAM_DATA_RANGE] k_itr; // An iterator to keep count of how many times weight matrix is traversed.

reg compute_start;
reg [`SRAM_DATA_RANGE] accum_result;
wire [`SRAM_DATA_RANGE] mac_result_z;
wire [2 : 0] inst_rnd;
reg write_en;

reg [1:0] last_state_counter; // Last two computations are done in the last state; keep a counter there
reg last_state_counter_sel;

/*----------------------Control Logic------------------------*/
`ifndef FSM_BIT_WIDTH
  `define FSM_BIT_WIDTH 3
`endif

typedef enum logic [`FSM_BIT_WIDTH-1:0] {
  IDLE  = `FSM_BIT_WIDTH'b000,
  READ_ADDRESS_START  = `FSM_BIT_WIDTH'b001,
  SET_COUNT_ITRS  = `FSM_BIT_WIDTH'b010,
  READ_DATA_START  = `FSM_BIT_WIDTH'b011,
  COMPUTE_START  = `FSM_BIT_WIDTH'b100,
  DO_COMPUTATION  = `FSM_BIT_WIDTH'b101,
  LAST_TWO_VALUES  = `FSM_BIT_WIDTH'b110
} e_states;

e_states current_state, next_state;

always @(posedge clk) begin
  if(!reset_n)
    current_state <= IDLE;
  else
    current_state <= next_state;
end

// Handshake logic
always @(posedge clk) begin
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
  compute_start = 1'b0;
  write_en = 1'b0;
  last_state_counter_sel = 1'b0;
  k_itr_sel = 1'b0;

  case (current_state)

    IDLE: begin
      if(dut_valid) begin
        next_state = READ_ADDRESS_START;
      end
      else begin
        set_dut_ready = 1'b1;
        next_state = IDLE;
      end
    end

    READ_ADDRESS_START: begin
      enable_sram_address_r = 1'b1;
      next_state = SET_COUNT_ITRS;
    end

    SET_COUNT_ITRS: begin
      input_col_itr_sel = 1'b1;
      weight_dim_itr_sel = 1'b1;

      next_state = READ_DATA_START;
    end

    READ_DATA_START: begin
      enable_sram_data_r = 1'b1;
      dimension_size_select = 1'b1;
      
      next_state = COMPUTE_START;
    end

    COMPUTE_START: begin
      enable_sram_data_r = 1'b1;
      compute_start = 1'b1;

      next_state = DO_COMPUTATION;
    end

    DO_COMPUTATION: begin
      enable_sram_data_r = 1'b1;
      input_col_itr_sel = ((input_col_itr+1) == input_col_dim);
      weight_dim_itr_sel = ((weight_dim_itr+1) == weight_matrix_dim);

      compute_start = ((input_col_itr) == 1);
      write_en = ((input_col_itr) == 1);

      k_itr_sel = ((weight_dim_itr + 2) == (weight_matrix_dim-1));

      /* k_itr determines if we should leave this state or not.
      * If it equals to the #input_rows means we have traversed the 
      * weight matrix input_rows times and are done now */
      if((k_itr) == input_row_dim) begin
        last_state_counter_sel = 1'b1;
        next_state = LAST_TWO_VALUES;
      end
      else
        next_state = DO_COMPUTATION;
    end

    LAST_TWO_VALUES: begin
      enable_sram_data_r = 1'b1;
      write_en = (last_state_counter == 1'b0);
      next_state = (last_state_counter == 1'b0) ? IDLE : LAST_TWO_VALUES;
    end

    default: begin
      set_dut_ready = 1'b1;
      next_state = IDLE;
    end
  endcase
end

/*----------------------Read SRAM Address------------------------*/
always @(posedge clk) begin
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

always @(posedge clk) begin
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
always @(posedge clk) begin
  if(!reset_n || compute_complete)
    input_data_r <= 0;
  else begin
    if(enable_sram_data_r)
      input_data_r <= tb__dut__sram_input_read_data;
    else
      input_data_r <= input_data_r;
  end
end

always @(posedge clk) begin
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
always @(posedge clk) begin
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
always @(posedge clk) begin
  if(!reset_n || compute_complete)
    input_col_itr <= 0;
  else
    if(input_col_itr_sel)
      input_col_itr <=0;
    else
      input_col_itr <= input_col_itr + 1'b1;
end

always @(posedge clk) begin
  if(!reset_n || compute_complete)
    weight_dim_itr <= 0;
  else
    if(weight_dim_itr_sel)
      weight_dim_itr <=0;
    else
      weight_dim_itr <= weight_dim_itr + 1'b1;
end

always @(posedge clk) begin
  if(!reset_n || compute_complete)
    k_itr <= 0;
  else
    if(k_itr_sel)
      k_itr <= k_itr + 1'b1;
    else
      k_itr <= k_itr;
end

/*----------------------MATH------------------------*/
always @(posedge clk) begin
  if(!reset_n || compute_complete)
    accum_result <= 0;
  else
    if(compute_start)
      accum_result <=0;
    else
      accum_result <= mac_result_z;
end

assign inst_rnd = 3'b0;
DW_fp_mac_inst 
  FP_MAC ( 
  .inst_a(input_data_r),
  .inst_b(weight_data_r),
  .inst_c(accum_result),
  .inst_rnd(inst_rnd),
  .z_inst(mac_result_z),
  .status_inst()
);

/*----------------------SRAM Write------------------------*/
always @(posedge clk) begin
  if(!reset_n || compute_complete)
    last_state_counter <= 0;
  else
    if(last_state_counter_sel)
      last_state_counter <=2;
    else
      last_state_counter <= last_state_counter - 1'b1;
end

always @(posedge clk) begin
  if(!reset_n || compute_complete)
    result_address_w <= 0;
  else
    if(write_en)
      result_address_w <= result_address_w + 1'b1;
    else
      result_address_w <=  result_address_w;
end

assign dut__tb__sram_result_write_enable = (write_en) ? 1'b1 : 1'b0;
assign dut__tb__sram_result_write_data = (write_en) ? mac_result_z : 32'bx;
assign dut__tb__sram_result_write_address = result_address_w;

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
