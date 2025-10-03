`timescale 1ns / 1ps

module PE_unit #(
    parameter DATA_WIDTH = 16, // As per paper's precision
    parameter ACCUM_WIDTH = 32 // Accumulator width to prevent overflow
) (
    input wire                      clk,
    input wire                      rst_n,
    input wire [1:0]                dataflow_sel, // 00: WS, 01: IS, 10: OS

    // Data Inputs
    input wire                      preload_en,   // preload data enable
    input wire [DATA_WIDTH-1:0]     preload_data, // preload data
    input wire [DATA_WIDTH-1:0]     input_0,      
    input wire [ACCUM_WIDTH-1:0]    input_1,      
    input wire [DATA_WIDTH-1:0]     input_2,     

    // Data Outputs
    output wire [DATA_WIDTH-1:0]    output_0,     
    output wire [ACCUM_WIDTH-1:0]   output_1,     
    output wire [DATA_WIDTH-1:0]    output_2    
);

    localparam WS_MODE = 2'b00;
    localparam IS_MODE = 2'b01;
    localparam OS_MODE = 2'b10;

    reg [DATA_WIDTH-1:0]   local_buffer; // Stores stationary data
    reg [ACCUM_WIDTH-1:0]  accumulator;  // accumulator for the MAC unit

    wire [DATA_WIDTH-1:0]  multiplier_in_A;
    wire [DATA_WIDTH-1:0]  multiplier_in_B;
    wire [ACCUM_WIDTH-1:0] adder_in_B;
    wire [ACCUM_WIDTH-1:0] mac_result;

    // Registered outputs for pipelining
    reg [DATA_WIDTH-1:0]   output_0_reg;
    reg [ACCUM_WIDTH-1:0]  output_1_reg;
    reg [DATA_WIDTH-1:0]   output_2_reg;

    // MUX for Multiplier (preload or input_0)
    assign multiplier_in_A = (dataflow_sel == OS_MODE)? input_0 : local_buffer;

    assign multiplier_in_B = input_2;

    // Mux for Adder (accumulator or input_1)
    assign adder_in_B = (dataflow_sel == OS_MODE)? accumulator : input_1;

    // mac_result = (A * B) + C
    assign mac_result = (multiplier_in_A * multiplier_in_B) + adder_in_B;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            local_buffer <= 0;
            accumulator  <= 0;
            output_0_reg <= 0;
            output_1_reg <= 0;
            output_2_reg <= 0;
        end else begin
            if (preload_en) begin
                local_buffer <= preload_data;
            end

            accumulator <= mac_result;

            case (dataflow_sel)
                WS_MODE: begin
                    output_0_reg <= 0; // Not used
                    output_1_reg <= mac_result; // PartialSum'
                    output_2_reg <= input_2;    // Input passes through
                end
                IS_MODE: begin
                    output_0_reg <= 0; // Not used
                    output_1_reg <= mac_result; // PartialSum'
                    output_2_reg <= input_2;    // Weight passes through
                end
                OS_MODE: begin
                    output_0_reg <= input_0;    // Weight passes through
                    output_1_reg <= 0; // Not used, result is stationary
                    output_2_reg <= input_2;    // Input passes through
                end
                default: begin
                    output_0_reg <= 0;
                    output_1_reg <= 0;
                    output_2_reg <= 0;
                end
            endcase
        end
    end

    assign output_0 = output_0_reg;
    assign output_1 = output_1_reg;
    assign output_2 = output_2_reg;

endmodule
