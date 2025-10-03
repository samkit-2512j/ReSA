`timescale 1ns / 1ps

module pe_tb();

    parameter DATA_WIDTH = 16;
    parameter ACCUM_WIDTH = 32;
    parameter CLK_PERIOD = 10;

    reg                      clk;
    reg                      rst_n;
    reg [1:0]                dataflow_sel;
    reg                      preload_en;
    reg [DATA_WIDTH-1:0]     preload_data;
    reg [DATA_WIDTH-1:0]     input_0;
    reg [DATA_WIDTH-1:0]     input_1;
    reg [DATA_WIDTH-1:0]     input_2;

    wire [DATA_WIDTH-1:0]    output_0;
    wire [ACCUM_WIDTH-1:0]   output_1;
    wire [DATA_WIDTH-1:0]    output_2;

    localparam WS_MODE = 2'b00;
    localparam IS_MODE = 2'b01;
    localparam OS_MODE = 2'b10;

    PE_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .dataflow_sel(dataflow_sel),
        .preload_en(preload_en),
        .preload_data(preload_data),
        .input_0(input_0),
        .input_1(input_1),
        .input_2(input_2),
        .output_0(output_0),
        .output_1(output_1),
        .output_2(output_2)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $dumpfile("pe_tb.vcd");
        $dumpvars(0, pe_tb);
        
        $display("=== PE Unit Testbench Started ===");
        
        clk = 0;
        rst_n = 0;
        dataflow_sel = 2'b00;
        preload_en = 0;
        preload_data = 0;
        input_0 = 0;
        input_1 = 0;
        input_2 = 0;
        
        #(CLK_PERIOD * 2);
        
        test_reset();
        test_preload();
        test_ws_mode();
        test_is_mode();
        test_os_mode();
        test_mac_operations();
        
        $display("=== All Tests Completed ===");
        $finish;
    end

    task test_reset();
        begin
            $display("\n--- Testing Reset Functionality ---");
            rst_n = 0;
            #(CLK_PERIOD);
            
            if (output_0 == 0 && output_1 == 0 && output_2 == 0) begin
                $display("PASS: Reset test - All outputs are 0");
            end else begin
                $display("FAIL: Reset test - Expected all outputs = 0, got output_0=%d, output_1=%d, output_2=%d", 
                        output_0, output_1, output_2);
            end
            
            rst_n = 1;
            #(CLK_PERIOD);
        end
    endtask

    task test_preload();
        begin
            $display("\n--- Testing Preload Functionality ---");
            rst_n = 1;
            dataflow_sel = WS_MODE;
            preload_en = 1;
            preload_data = 16'h1234;
            
            #(CLK_PERIOD);
            preload_en = 0;
            
            input_2 = 16'h0002;
            input_1 = 16'h0000;
            
            #(CLK_PERIOD);
            
            if (output_1 == (16'h1234 * 16'h0002)) begin
                $display("PASS: Preload test - Local buffer correctly loaded and used in MAC");
            end else begin
                $display("FAIL: Preload test - Expected %d, got %d", 
                        (16'h1234 * 16'h0002), output_1);
            end
        end
    endtask

    task test_ws_mode();
        begin
            $display("\n--- Testing Weight Stationary Mode ---");
            rst_n = 0;
            #(CLK_PERIOD);
            rst_n = 1;
            
            dataflow_sel = WS_MODE;
            preload_en = 1;
            preload_data = 16'h0005;
            #(CLK_PERIOD);
            preload_en = 0;
            
            input_0 = 16'h1111;
            input_1 = 16'h0010;
            input_2 = 16'h0003;
            
            #(CLK_PERIOD);
            
            $display("WS Mode Results:");
            $display("  output_0 = %d (expected: 0)", output_0);
            $display("  output_1 = %d (expected: %d)", output_1, (16'h0005 * 16'h0003 + 16'h0010));
            $display("  output_2 = %d (expected: %d)", output_2, 16'h0003);
            
            if (output_0 == 0 && 
                output_1 == (16'h0005 * 16'h0003 + 16'h0010) && 
                output_2 == 16'h0003) begin
                $display("PASS: WS Mode test");
            end else begin
                $display("FAIL: WS Mode test");
            end
        end
    endtask

    task test_is_mode();
        begin
            $display("\n--- Testing Input Stationary Mode ---");
            rst_n = 0;
            #(CLK_PERIOD);
            rst_n = 1;
            
            dataflow_sel = IS_MODE;
            preload_en = 1;
            preload_data = 16'h0007;
            #(CLK_PERIOD);
            preload_en = 0;
            
            input_0 = 16'h2222;
            input_1 = 16'h0020;
            input_2 = 16'h0004;
            
            #(CLK_PERIOD);
            
            $display("IS Mode Results:");
            $display("  output_0 = %d (expected: 0)", output_0);
            $display("  output_1 = %d (expected: %d)", output_1, (16'h0007 * 16'h0004 + 16'h0020));
            $display("  output_2 = %d (expected: %d)", output_2, 16'h0004);
            
            if (output_0 == 0 && 
                output_1 == (16'h0007 * 16'h0004 + 16'h0020) && 
                output_2 == 16'h0004) begin
                $display("PASS: IS Mode test");
            end else begin
                $display("FAIL: IS Mode test");
            end
        end
    endtask

    task test_os_mode();
        begin
            $display("\n--- Testing Output Stationary Mode ---");
            rst_n = 0;
            #(CLK_PERIOD);
            rst_n = 1;
            
            dataflow_sel = OS_MODE;
            preload_en = 1;
            preload_data = 16'h0009;
            #(CLK_PERIOD);
            preload_en = 0;
            
            input_0 = 16'h0006;
            input_1 = 16'h0030;
            input_2 = 16'h0005;
            
            #(CLK_PERIOD);
            
            $display("OS Mode Results (Cycle 1):");
            $display("  output_0 = %d (expected: %d)", output_0, 16'h0006);
            $display("  output_1 = %d (expected: 0)", output_1);
            $display("  output_2 = %d (expected: %d)", output_2, 16'h0005);
            
            input_0 = 16'h0008;
            input_2 = 16'h0003;
            #(CLK_PERIOD);
            
            $display("OS Mode Results (Cycle 2 - Accumulation):");
            $display("  output_0 = %d (expected: %d)", output_0, 16'h0008);
            $display("  output_2 = %d (expected: %d)", output_2, 16'h0003);
            
            if (output_0 == 16'h0008 && output_1 == 0 && output_2 == 16'h0003) begin
                $display("PASS: OS Mode test");
            end else begin
                $display("FAIL: OS Mode test");
            end
        end
    endtask

    task test_mac_operations();
        begin
            $display("\n--- Testing MAC Operations ---");
            rst_n = 0;
            #(CLK_PERIOD);
            rst_n = 1;
            
            dataflow_sel = WS_MODE;
            preload_en = 1;
            preload_data = 16'd10;
            #(CLK_PERIOD);
            preload_en = 0;
            
            input_1 = 32'd100;
            input_2 = 16'd5;
            #(CLK_PERIOD);
            
            $display("MAC Test: (10 * 5) + 100 = %d (expected: 150)", output_1);
            
            if (output_1 == 150) begin
                $display("PASS: MAC operation test");
            end else begin
                $display("FAIL: MAC operation test - Expected 150, got %d", output_1);
            end
            
            input_1 = 32'd200;
            input_2 = 16'd3;
            #(CLK_PERIOD);
            
            $display("MAC Test: (10 * 3) + 200 = %d (expected: 230)", output_1);
            
            if (output_1 == 230) begin
                $display("PASS: Second MAC operation test");
            end else begin
                $display("FAIL: Second MAC operation test - Expected 230, got %d", output_1);
            end
        end
    endtask

endmodule