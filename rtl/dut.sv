//---------------------------------------------------------------------------
// DUT - project 
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
  output wire signed [`SRAM_DATA_RANGE     ]   dut__tb__sram_input_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_input_read_address  , 
  input  wire signed [`SRAM_DATA_RANGE     ]   tb__dut__sram_input_read_data     ,     

//weight SRAM interface
  output wire                           dut__tb__sram_weight_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_write_address ,
  output wire signed [`SRAM_DATA_RANGE     ]   dut__tb__sram_weight_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_read_address  , 
  input  wire signed [`SRAM_DATA_RANGE     ]   tb__dut__sram_weight_read_data     ,     

//result SRAM interface
  output wire                           dut__tb__sram_result_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_write_address ,
  output wire signed [`SRAM_DATA_RANGE     ]   dut__tb__sram_result_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_read_address  , 
  input  wire signed [`SRAM_DATA_RANGE     ]   tb__dut__sram_result_read_data    ,      

//scratchpad SRAM interface
  output wire                           dut__tb__sram_scratchpad_write_enable  ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_scratchpad_write_address ,
  output wire signed [`SRAM_DATA_RANGE     ]   dut__tb__sram_scratchpad_write_data    ,
  output wire [`SRAM_ADDR_RANGE     ]   dut__tb__sram_scratchpad_read_address  , 
  input  wire signed [`SRAM_DATA_RANGE     ]   tb__dut__sram_scratchpad_read_data          
);

/*----------------------Local Variables Declaration------------------------*/

// Two flags to for handshake logic
reg compute_complete;
reg set_dut_ready;

reg enable_sram_address_r;
reg [`SRAM_ADDR_RANGE     ] input_address_r;
reg [`SRAM_ADDR_RANGE     ]  weight_address_r;
reg [`SRAM_ADDR_RANGE     ]  result_address_w;
reg [`SRAM_ADDR_RANGE     ]  scratchpad_address_w;

reg enable_sram_data_r;
reg signed [`SRAM_DATA_RANGE] input_data_r;
reg signed [`SRAM_DATA_RANGE] weight_data_r;

reg [1:0] dimension_size_select;  // Flag to load dimensions of both arrays in the below variables
reg [`SRAM_ADDR_RANGE] input_row_dim;
reg [`SRAM_ADDR_RANGE] input_col_dim;
reg [`SRAM_ADDR_RANGE] weight_col_dim;
reg [`SRAM_ADDR_RANGE] weight_matrix_dim;
reg [`SRAM_ADDR_RANGE] result_matrix_dim;

reg input_col_itr_sel;
reg [`SRAM_ADDR_RANGE] input_col_itr;
reg weight_dim_itr_sel;
reg [`SRAM_ADDR_RANGE] weight_dim_itr;
reg input_row_itr_sel;
reg [`SRAM_ADDR_RANGE] input_row_itr;

reg compute_start;
reg signed [`SRAM_DATA_RANGE] accum_result;
wire signed [`SRAM_DATA_RANGE] mac_result_z;
reg result_write_en;

reg [1:0] last_state_counter; // Last two computations are done in the last state; keep a counter there
reg last_state_counter_sel;

reg which_weight_count_sel;
reg [1:0] which_weight_count;

wire input_matrix_traversed;
reg set_weight_count_zero;

reg s_addr_comp;
reg sz_data_comp;
reg z_addr_comp;
reg z_col_itr;
/*----------------------Control Logic------------------------*/
`ifndef FSM_BIT_WIDTH
  `define FSM_BIT_WIDTH 4
`endif

typedef enum logic [`FSM_BIT_WIDTH-1:0] {
  IDLE  = `FSM_BIT_WIDTH'b0000,
  READ_ADDRESS_START  = `FSM_BIT_WIDTH'b0001,
  SET_COUNT_ITRS  = `FSM_BIT_WIDTH'b0010,
  READ_DATA_START  = `FSM_BIT_WIDTH'b0011,
  COMPUTE_START  = `FSM_BIT_WIDTH'b0100,
  QKV_COMPUTATION  = `FSM_BIT_WIDTH'b0101,
  BUFFER_STATE_1  = `FSM_BIT_WIDTH'b0110,
  S_COMPUTATION = `FSM_BIT_WIDTH'b0111,
  BUFFER_STATE_2 = `FSM_BIT_WIDTH'b1000,
  Z_COMPUTATION = `FSM_BIT_WIDTH'b1001,
  LAST_TWO_VALUES = `FSM_BIT_WIDTH'b1010
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
  dimension_size_select = 2'b00;
  input_col_itr_sel = 1'b0;
  weight_dim_itr_sel = 1'b0;
  compute_start = 1'b0;
  result_write_en = 1'b0;
  last_state_counter_sel = 1'b0;
  input_row_itr_sel = 1'b0;
  which_weight_count_sel = 1'b0;
  set_weight_count_zero = 1'b0;
  s_addr_comp = 1'b0;
  sz_data_comp = 1'b0;
  z_addr_comp = 1'b0;
  z_col_itr = 1'b0;

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
      dimension_size_select = 2'b01;
      
      next_state = COMPUTE_START;
    end

    COMPUTE_START: begin
      enable_sram_data_r = 1'b1;
      compute_start = 1'b1;

      next_state = QKV_COMPUTATION;
    end

    QKV_COMPUTATION: begin
      enable_sram_data_r = 1'b1;
      input_col_itr_sel = ((input_col_itr+1) == input_col_dim);
      weight_dim_itr_sel = ((weight_dim_itr+1) == weight_matrix_dim);

      compute_start = ((input_col_itr) == 1);
      result_write_en = ((input_col_itr) == 1);

      input_row_itr_sel = ((weight_dim_itr + 2) == (weight_matrix_dim-1));

      if(input_matrix_traversed) begin
        if(which_weight_count == 2) begin
          last_state_counter_sel = 1'b1;
          next_state = BUFFER_STATE_1;
        end
        else begin
          which_weight_count_sel = 1'b1;
          next_state = QKV_COMPUTATION;
        end
      end
      else
        next_state = QKV_COMPUTATION;
    end

    BUFFER_STATE_1: begin
      enable_sram_data_r = 1'b1;
      
      enable_sram_address_r = 1'b1;

      input_col_itr_sel = 1'b1;
      weight_dim_itr_sel = 1'b1;
      dimension_size_select = 2'b10;
      set_weight_count_zero = 1'b1;

      next_state = S_COMPUTATION;
    end

    S_COMPUTATION: begin
      s_addr_comp = 1'b1;
      sz_data_comp = (last_state_counter == 0) ? 1'b1 : 1'b0;
      enable_sram_data_r = 1'b1;
      
      input_col_itr_sel = ((input_col_itr+1) == input_col_dim);
      weight_dim_itr_sel = ((weight_dim_itr+1) == weight_matrix_dim);
      input_row_itr_sel = ((weight_dim_itr + 2) == (weight_matrix_dim-1));
      
      result_write_en = ((input_col_itr) == 1);
      compute_start = ((input_col_itr) == 1);

      if(input_matrix_traversed) begin
        last_state_counter_sel = 1'b1;
        next_state = BUFFER_STATE_2;
      end
      else
        next_state = S_COMPUTATION;
    end

    BUFFER_STATE_2: begin
      s_addr_comp = 1'b1;
      sz_data_comp = 1'b1;
      enable_sram_data_r = 1'b1;

      input_col_itr_sel = ((input_col_itr+1) == input_col_dim);
      
      result_write_en = ((input_col_itr) == 1);
      compute_start = ((input_col_itr) == 1);
      
      if (last_state_counter == 1'b0) begin
        input_col_itr_sel = 1'b1;
        weight_dim_itr_sel = 1'b1;
        dimension_size_select = 2'b11;
        set_weight_count_zero = 1'b1;
        z_addr_comp = 1'b1;
        enable_sram_address_r = 1'b1;
        z_col_itr = 1'b1;
        last_state_counter_sel = 1'b1;
        next_state = Z_COMPUTATION;
      end
      else
        next_state = BUFFER_STATE_2;
    end

    Z_COMPUTATION : begin

      enable_sram_data_r = 1'b1;
      z_addr_comp = 1'b1;
      sz_data_comp = 1'b1;
      
      input_col_itr_sel = ((input_col_itr+1) == input_col_dim);
      weight_dim_itr_sel = ((input_col_itr+1) == input_col_dim);
      
      z_col_itr = (((weight_dim_itr + 1) == weight_col_dim) && (input_col_itr+1) == input_col_dim);

      if(input_row_dim == 1) begin
        input_row_itr_sel = ((weight_dim_itr + 1) == weight_col_dim);
        result_write_en = (last_state_counter !=1 && weight_dim_itr >= 2);
        compute_start = (weight_dim_itr >= 1);
      end
      else begin
        input_row_itr_sel = (((weight_dim_itr + 1) == weight_col_dim) && (input_col_itr+2) == input_col_dim);
        result_write_en = (last_state_counter !=1 && input_col_itr == 1);
        compute_start = (input_col_itr == 1);
      end

      if(input_matrix_traversed) begin
        if(input_row_dim == 1) begin
          result_write_en = 1'b1;
          compute_start = 1'b1;
        end
        last_state_counter_sel = 1'b1;
        next_state = LAST_TWO_VALUES;
      end
      else
        next_state = Z_COMPUTATION;
    end

    LAST_TWO_VALUES: begin
      enable_sram_data_r = 1'b1;
      sz_data_comp = 1'b1;
      if(input_row_dim == 1) begin
        result_write_en = 1'b1;
        next_state = IDLE;
      end
      else begin
      result_write_en = (input_col_itr == 1);
      next_state = (last_state_counter == 1'b0) ? IDLE : LAST_TWO_VALUES;
      end
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
      if (z_addr_comp)
        input_address_r <= 3*result_matrix_dim;
      else
        input_address_r <= 0;
    else if(input_col_itr_sel)
      if(s_addr_comp)
        input_address_r <= input_col_dim * input_row_itr;
      else if(z_addr_comp)
        input_address_r <= (3*result_matrix_dim) + (input_col_dim * input_row_itr);
      else  
        input_address_r <= (input_col_dim * input_row_itr) + 1'b1;
    else
      input_address_r <= input_address_r + 1'b1;
  end
end
assign dut__tb__sram_input_read_address = (s_addr_comp || z_addr_comp) ? 16'bx : input_address_r;
assign dut__tb__sram_result_read_address = (s_addr_comp || z_addr_comp) ? input_address_r : 16'bx;

always @(posedge clk) begin
  if(!reset_n || compute_complete)
    weight_address_r <= 0;
  else begin
    if(enable_sram_address_r || z_col_itr)
      if(z_addr_comp)
        weight_address_r <= result_matrix_dim;
      else
      weight_address_r <= 0;
    else if(weight_dim_itr_sel)
      if (s_addr_comp)
        weight_address_r <= 0;
      else if(z_addr_comp)
        weight_address_r <= result_matrix_dim + weight_dim_itr + 1;
      else
        weight_address_r <= (weight_matrix_dim * which_weight_count) + 1;
    else
      if(z_addr_comp)
        weight_address_r <= weight_address_r + weight_col_dim;
      else
        weight_address_r <= weight_address_r + 1'b1;
  end
end
assign dut__tb__sram_weight_read_address = (s_addr_comp || z_addr_comp) ? 16'bx : weight_address_r;
assign dut__tb__sram_scratchpad_read_address = (s_addr_comp || z_addr_comp) ? weight_address_r : 16'bx;

/*----------------------Read SRAM Data------------------------*/
always @(posedge clk) begin
  if(!reset_n || compute_complete)
    input_data_r <= 0;
  else begin
    if(enable_sram_data_r)
      input_data_r <= (sz_data_comp) ? tb__dut__sram_result_read_data : tb__dut__sram_input_read_data;
    else
      input_data_r <= input_data_r;
  end
end

always @(posedge clk) begin
  if(!reset_n || compute_complete)
    weight_data_r <= 0;
  else begin
    if(enable_sram_data_r)
      weight_data_r <= (sz_data_comp) ? tb__dut__sram_scratchpad_read_data : tb__dut__sram_weight_read_data;
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
    result_matrix_dim <=0;
  end
  else begin
    if(dimension_size_select == 2'b01) begin
      input_row_dim <= tb__dut__sram_input_read_data[31:16];
      input_col_dim <= tb__dut__sram_input_read_data[15:0];
      weight_col_dim <= tb__dut__sram_weight_read_data[15:0];
      weight_matrix_dim <= tb__dut__sram_weight_read_data[15:0] * tb__dut__sram_weight_read_data[31:16];
      result_matrix_dim <= tb__dut__sram_input_read_data[31:16] * tb__dut__sram_weight_read_data[15:0];
    end
    else if(dimension_size_select == 2'b10) begin
      input_col_dim <= weight_col_dim;
      weight_col_dim <= input_row_dim;
      weight_matrix_dim <= weight_col_dim * input_row_dim;
    end
    else if(dimension_size_select == 2'b11) begin
      input_col_dim <= input_row_dim;
      weight_col_dim <= input_col_dim;
    end
    else begin
      input_row_dim <= input_row_dim;
      input_col_dim <= input_col_dim;
      weight_col_dim <= weight_col_dim;
      weight_matrix_dim <= weight_matrix_dim;
      result_matrix_dim <= result_matrix_dim;
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
    if(z_addr_comp)
      if(z_col_itr)
        weight_dim_itr <= 0;
      else if(weight_dim_itr_sel)
        weight_dim_itr <= weight_dim_itr + 1'b1;
      else
        weight_dim_itr <= weight_dim_itr;
    else
      if(weight_dim_itr_sel)
        weight_dim_itr <=0;
      else
        weight_dim_itr <= weight_dim_itr + 1'b1;
end

always @(posedge clk) begin
  if(!reset_n || compute_complete || which_weight_count_sel || set_weight_count_zero)
    input_row_itr <= 0;
  else
    if(input_row_itr_sel)
      input_row_itr <= input_row_itr + 1'b1;
    else
      input_row_itr <= input_row_itr;
end

always @(posedge clk) begin
  if(!reset_n || compute_complete || set_weight_count_zero)
    which_weight_count <= 0;
  else
    if(which_weight_count_sel)
      which_weight_count <= which_weight_count + 1'b1;
    else
      which_weight_count <= which_weight_count;
end

assign input_matrix_traversed = ((input_row_itr) == input_row_dim);
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

assign mac_result_z = (input_data_r * weight_data_r) + accum_result;

/*----------------------SRAM Write------------------------*/
always @(posedge clk) begin
  if(!reset_n || compute_complete)
    last_state_counter <= 0;
  else
    if(last_state_counter_sel)
      last_state_counter <=2;
    else if(last_state_counter > 0)
      last_state_counter <= last_state_counter - 1'b1;
end

always @(posedge clk) begin
  if(!reset_n || compute_complete)
    result_address_w <= 0;
  else
    if(result_write_en)
      result_address_w <= result_address_w + 1'b1;
    else
      result_address_w <=  result_address_w;
end

assign dut__tb__sram_result_write_enable = (result_write_en) ? 1'b1 : 1'b0;
assign dut__tb__sram_result_write_address = result_address_w;
assign dut__tb__sram_result_write_data = (result_write_en) ? mac_result_z : 32'bx;

always @(posedge clk) begin
  if(!reset_n || compute_complete)
    scratchpad_address_w <= 0;
  else
    if(dut__tb__sram_scratchpad_write_enable)
      scratchpad_address_w <= scratchpad_address_w + 1'b1;
    else
      scratchpad_address_w <=  scratchpad_address_w;
end

assign dut__tb__sram_scratchpad_write_enable = ((result_address_w >= result_matrix_dim && result_address_w < 3*result_matrix_dim) && (input_col_itr == 1)) ? 1'b1 : 1'b0;
assign dut__tb__sram_scratchpad_write_address = scratchpad_address_w;
assign dut__tb__sram_scratchpad_write_data = (dut__tb__sram_scratchpad_write_enable) ? mac_result_z : 32'bx;

endmodule
