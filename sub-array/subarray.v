module sub_array #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter DATA_WIDTH = 16,
    parameter ACCUM_WIDTH = 32
) (
    // System Signals
    input wire clk,
    input wire rst,

    // Control Signals (broadcast to all PEs in this sub-array)
    input wire [1:0] dataflow_sel,
    input wire stationary_sel,

    // Array Data Inputs (from North and West boundaries)
    input wire signed [COLS-1:0][DATA_WIDTH-1:0] array_ifmap_in,
    input wire signed [ROWS-1:0][DATA_WIDTH-1:0] array_weight_in,
    input wire signed [COLS-1:0][ACCUM_WIDTH-1:0] array_psum_in_v,
    input wire signed [ROWS-1:0][ACCUM_WIDTH-1:0] array_psum_in_h,

    // Array Data Outputs (to South and East boundaries)
    output wire signed [COLS-1:0][DATA_WIDTH-1:0] array_ifmap_out,
    output wire signed [ROWS-1:0][DATA_WIDTH-1:0] array_weight_out,
    output wire signed [COLS-1:0][ACCUM_WIDTH-1:0] array_psum_out_v,
    output wire signed [ROWS-1:0][ACCUM_WIDTH-1:0] array_psum_out_h
);

    // Internal wires for connecting the PEs
    wire signed [ROWS:0][COLS:0][DATA_WIDTH-1:0] ifmap_wires;
    wire signed [ROWS:0][COLS:0][DATA_WIDTH-1:0] weight_wires;
    wire signed [ROWS:0][COLS:0][ACCUM_WIDTH-1:0] psum_v_wires;
    wire signed [ROWS:0][COLS:0][ACCUM_WIDTH-1:0] psum_h_wires;

    // Generate loop to create the 2D array of PEs
    genvar r, c;
    generate
        for (r = 0; r < ROWS; r = r + 1) begin: row_gen
            for (c = 0; c < COLS; c = c + 1) begin: col_gen
                
                // Instantiate one Processing Element
                PE_unit #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACCUM_WIDTH(ACCUM_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .rst_n(~rst),
                    .dataflow_sel(dataflow_sel),
                    
                    // Preload logic - use stationary_sel to control preloading
                    .preload_en(stationary_sel),
                    .preload_data((dataflow_sel == 2'b00) ? ifmap_wires[r][c] : weight_wires[r][c]),

                    // Map systolic array inputs to PE_unit inputs based on dataflow mode
                    .input_0(ifmap_wires[r][c]),     // Input feature map (from West)
                    .input_1(psum_h_wires[r][c]),    // Partial sum horizontal (from West)
                    .input_2(weight_wires[r][c]),    // Weight (from North)

                    // Map PE_unit outputs to systolic array outputs
                    .output_0(ifmap_wires[r][c+1]),  // To East
                    .output_1(psum_v_wires[r+1][c]), // To South (vertical psum)
                    .output_2(weight_wires[r+1][c])  // To South
                );
                
                // Handle horizontal partial sum output
                assign psum_h_wires[r][c+1] = psum_h_wires[r][c];
            end
        end
    endgenerate

    // Connect the boundaries of the PE grid to the module's I/O ports
    genvar i;
    generate
        for (i = 0; i < COLS; i = i + 1) begin: boundary_col_connect
            // Connect North inputs
            assign weight_wires[0][i] = array_weight_in[i];
            assign psum_v_wires[0][i] = array_psum_in_v[i];
            // Connect South outputs
            assign array_weight_out[i] = weight_wires[ROWS][i];
            assign array_psum_out_v[i] = psum_v_wires[ROWS][i];
        end
        for (i = 0; i < ROWS; i = i + 1) begin: boundary_row_connect
            // Connect West inputs
            assign ifmap_wires[i][0] = array_ifmap_in[i];
            assign psum_h_wires[i][0] = array_psum_in_h[i];
            // Connect East outputs
            assign array_ifmap_out[i] = ifmap_wires[i][COLS];
            assign array_psum_out_h[i] = psum_h_wires[i][COLS];
        end
    endgenerate

endmodule
 