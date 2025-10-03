module pe_block #(
    parameter DATA_WIDTH = 8,
    parameter ACCUM_WIDTH = 32
) (
    // System Signals
    input wire clk,
    input wire rst,

    // Control Signals for Reconfiguration
    input wire [1:0] dataflow_sel, // 00: OS, 01: WS, 10: IS
    input wire stationary_sel,     // 1: Hold stationary data, 0: Load new data

    // Data Inputs
    input wire signed [DATA_WIDTH-1:0] ifmap_in,    // Input Feature Map from West
    input wire signed [DATA_WIDTH-1:0] weight_in,   // Weight from North
    input wire signed [ACCUM_WIDTH-1:0] psum_in_v,   // Partial Sum from North (for OS)
    input wire signed [ACCUM_WIDTH-1:0] psum_in_h,   // Partial Sum from West (for IS/WS)

    // Data Outputs
    output wire signed [DATA_WIDTH-1:0] ifmap_out,   // To East
    output wire signed [DATA_WIDTH-1:0] weight_out,  // To South
    output wire signed [ACCUM_WIDTH-1:0] psum_out_v,  // To South
    output wire signed [ACCUM_WIDTH-1:0] psum_out_h   // To East
);

    // Dataflow constants for clarity
    localparam OS_MODE = 2'b00;
    localparam WS_MODE = 2'b01;
    localparam IS_MODE = 2'b10;

    // Internal Registers
    reg signed [DATA_WIDTH-1:0] ifmap_reg;
    reg signed [DATA_WIDTH-1:0] weight_reg;
    reg signed [ACCUM_WIDTH-1:0] psum_reg;

    // Wires for intermediate values
    wire signed [ACCUM_WIDTH-1:0] psum_in_selected;
    wire signed [(DATA_WIDTH*2)-1:0] mac_mult_result;
    wire signed [ACCUM_WIDTH-1:0] mac_add_result;

    // --- 1. Stationary Register Logic ---
    // These MUXes and registers hold the "stationary" data based on the dataflow mode.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ifmap_reg  <= 0;
            weight_reg <= 0;
            psum_reg   <= 0;
        end else begin
            // Input Stationary: Hold ifmap_reg if stationary_sel is high
            if (dataflow_sel == IS_MODE && stationary_sel) begin
                ifmap_reg <= ifmap_reg;
            end else begin
                ifmap_reg <= ifmap_in;
            end

            // Weight Stationary: Hold weight_reg if stationary_sel is high
            if (dataflow_sel == WS_MODE && stationary_sel) begin
                weight_reg <= weight_reg;
            end else begin
                weight_reg <= weight_in;
            end

            // Output Stationary: The psum is held in psum_reg
            // In other modes, it just passes through.
            psum_reg <= mac_add_result;
        end
    end

    // --- 2. MAC Unit ---
    // Select the correct incoming Partial Sum based on dataflow
    assign psum_in_selected = (dataflow_sel == OS_MODE) ? psum_in_v : psum_in_h;
    
    // Multiply and Accumulate operation
    assign mac_mult_result = ifmap_reg * weight_reg;
    assign mac_add_result = mac_mult_result + psum_in_selected;

    // --- 3. Output Logic ---
    // These assignments define the data propagation to neighboring PEs.
    // Data is passed from the registers.
    assign ifmap_out  = ifmap_reg;
    assign weight_out = weight_reg;

    // The calculated psum result is passed out based on dataflow direction.
    assign psum_out_h = (dataflow_sel == IS_MODE || dataflow_sel == WS_MODE) ? psum_reg : 0;
    assign psum_out_v = (dataflow_sel == OS_MODE) ? psum_reg : 0;

endmodule