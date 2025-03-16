`timescale 1ns / 1ps

module time_based_processor_simple_tb;

    // Parameters
    parameter CLK_PERIOD = 10; // 10ns (100MHz) clock period
    
    // DUT Signals
    reg         clk;
    reg         rst_n;
    reg  [7:0]  data_in;
    reg  [2:0]  opcode;
    reg         data_valid;
    wire [15:0] data_out;
    wire        data_ready;
    wire [3:0]  status_flags;
    
    // Instantiate the DUT
    time_based_processor DUT (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .opcode(opcode),
        .data_valid(data_valid),
        .data_out(data_out),
        .data_ready(data_ready),
        .status_flags(status_flags)
    );
    
    // Clock generator
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Task for applying inputs
    task apply_operation;
        input [2:0] op;
        input [7:0] input_a;
        input [7:0] input_b;
        input       needs_second_input;
        
        begin
            // First operand and opcode
            @(posedge clk);
            data_in = input_a;
            opcode = op;
            data_valid = 1'b1;
            
            @(posedge clk);
            data_valid = 1'b0;
            
            // If operation needs second operand
            if (needs_second_input) begin
                // Wait a bit before sending second operand
                repeat(3) @(posedge clk);
                
                // Second operand
                @(posedge clk);
                data_in = input_b;
                data_valid = 1'b1;
                
                @(posedge clk);
                data_valid = 1'b0;
            end
            
            // Wait for result to be ready
            wait(data_ready);
            
            // Display result
            $display("Operation: %d, Input A: %h, Input B: %h, Result: %h, Flags: %b", 
                     op, input_a, input_b, data_out, status_flags);
            
            // Wait a bit before next operation
            repeat(5) @(posedge clk);
        end
    endtask
    
    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        data_in = 8'h00;
        opcode = 3'b000;
        data_valid = 0;
        
        // Apply reset
        #20 rst_n = 1;
        
        // Wait for a few clock cycles
        repeat(5) @(posedge clk);
        
        // Apply different operations
        
        // Test NOP (0)
        apply_operation(3'b000, 8'h55, 8'h00, 0);
        
        // Test ADD (1) - Regular
        apply_operation(3'b001, 8'h23, 8'h45, 1);
        
        // Test ADD (1) - With overflow
        apply_operation(3'b001, 8'hFF, 8'h01, 1);
        
        // Test SUB (2) - Regular
        apply_operation(3'b010, 8'h45, 8'h23, 1);
        
        // Test SUB (2) - With underflow
        apply_operation(3'b010, 8'h23, 8'h45, 1);
        
        // Test MUL (3) - Regular
        apply_operation(3'b011, 8'h05, 8'h04, 1);
        
        // Test MUL (3) - With overflow
        apply_operation(3'b011, 8'h23, 8'h45, 1);
        
        // Test SHIFT (4) - Left shift
        apply_operation(3'b100, 8'h05, 8'h01, 1);
        
        // Test SHIFT (4) - Right shift
        apply_operation(3'b100, 8'h08, 8'h09, 1);
        
        // Test FILTER (5)
        apply_operation(3'b101, 8'hAA, 8'h55, 1);
        
        // Test INVERT (6)
        apply_operation(3'b110, 8'hAA, 8'h00, 0);
        
        // Test COMPARE (7) - A > B
        apply_operation(3'b111, 8'h23, 8'h22, 1);
        
        // Test COMPARE (7) - A < B
        apply_operation(3'b111, 8'h22, 8'h23, 1);
        
        // Test COMPARE (7) - A = B
        apply_operation(3'b111, 8'h23, 8'h23, 1);
        
        // End simulation
        #100 $finish;
    end
    
endmodule