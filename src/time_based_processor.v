`timescale 1ns / 1ps

module time_based_processor(
    input           clk,            // Clock input
    input           rst_n,          // Active-low reset
    input  [7:0]    data_in,        // 8-bit data input
    input  [2:0]    opcode,         // 3-bit operation code
    input           data_valid,     // Input data valid signal
    output [15:0]   data_out,       // 16-bit data output
    output          data_ready,     // Output data ready signal
    output [3:0]    status_flags    // Status flags [overflow, zero, reserved, complete]
);

    // Operation codes
    localparam OP_NOP     = 3'b000;  // No operation (pass through)
    localparam OP_ADD     = 3'b001;  // Addition
    localparam OP_SUB     = 3'b010;  // Subtraction
    localparam OP_MUL     = 3'b011;  // Multiplication
    localparam OP_SHIFT   = 3'b100;  // Shift operation
    localparam OP_FILTER  = 3'b101;  // Filter operation
    localparam OP_INVERT  = 3'b110;  // Invert operation
    localparam OP_COMPARE = 3'b111;  // Compare operation
    
    // State definitions
    localparam IDLE        = 2'b00;
    localparam WAIT_SECOND = 2'b01;
    localparam PROCESSING  = 2'b10;
    localparam COMPLETE    = 2'b11;
    
    // Internal registers
    reg [1:0]  state, next_state;
    reg [7:0]  operand_a;
    reg [7:0]  operand_b;
    reg [2:0]  current_opcode;
    reg [15:0] result;
    reg        result_ready;
    reg [3:0]  flags;
    
    // Flag bit positions
    localparam FLAG_OVERFLOW = 3;
    localparam FLAG_ZERO     = 2;
    localparam FLAG_RESERVED = 1;
    localparam FLAG_COMPLETE = 0;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            operand_a <= 8'h00;
            operand_b <= 8'h00;
            current_opcode <= 3'b000;
            result <= 16'h0000;
            result_ready <= 1'b0;
            flags <= 4'b0000;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_ready <= 1'b0;
                    flags <= 4'b0000;
                    
                    if (data_valid) begin
                        operand_a <= data_in;
                        current_opcode <= opcode;
                        
                        // For operations that don't need second operand
                        if (opcode == OP_INVERT || opcode == OP_NOP) begin
                            next_state <= PROCESSING;
                        end else begin
                            next_state <= WAIT_SECOND;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                WAIT_SECOND: begin
                    if (data_valid) begin
                        operand_b <= data_in;
                        next_state <= PROCESSING;
                    end else begin
                        next_state <= WAIT_SECOND;
                    end
                end
                
                PROCESSING: begin
                    case (current_opcode)
                        OP_NOP: begin
                            // Simply pass through operand_a
                            result <= {8'h00, operand_a};
                            flags[FLAG_COMPLETE] <= 1'b1;
                        end
                        
                        OP_ADD: begin
                            // Addition with overflow detection
                            {flags[FLAG_OVERFLOW], result[7:0]} <= operand_a + operand_b;
                            result[15:8] <= 8'h00;
                            flags[FLAG_COMPLETE] <= 1'b1;
                            flags[FLAG_ZERO] <= (operand_a + operand_b == 0);
                        end
                        
                        OP_SUB: begin
                            // Subtraction with underflow detection
                            result[7:0] <= operand_a - operand_b;
                            result[15:8] <= 8'h00;
                            flags[FLAG_COMPLETE] <= 1'b1;
                            flags[FLAG_OVERFLOW] <= (operand_a < operand_b);
                            flags[FLAG_ZERO] <= (operand_a == operand_b);
                        end
                        
                        OP_MUL: begin
                            // Multiplication with overflow detection
                            result <= operand_a * operand_b;
                            flags[FLAG_COMPLETE] <= 1'b1;
                            flags[FLAG_OVERFLOW] <= ((operand_a * operand_b) > 8'hFF);
                            flags[FLAG_ZERO] <= ((operand_a * operand_b) == 0);
                        end
                        
                        OP_SHIFT: begin
                            // Shift operation - bit 3 of operand_b determines direction
                            if (operand_b[3]) begin
                                // Right shift
                                result[7:0] <= operand_a >> (operand_b[2:0]);
                            end else begin
                                // Left shift
                                result[7:0] <= operand_a << (operand_b[2:0]);
                            end
                            result[15:8] <= 8'h00;
                            flags[FLAG_COMPLETE] <= 1'b1;
                        end
                        
                        OP_FILTER: begin
                            // Filter operation - implementation based on testbench expectations
                            // For this implementation, we'll assume a simple filter operation
                            // (e.g., bitwise AND) but this could be modified based on actual requirements
                            result[7:0] <= operand_a & operand_b;
                            result[15:8] <= 8'h00;
                            flags[FLAG_COMPLETE] <= 1'b1;
                        end
                        
                        OP_INVERT: begin
                            // Invert operation (bitwise NOT)
                            result[7:0] <= ~operand_a;
                            result[15:8] <= 8'h00;
                            flags[FLAG_COMPLETE] <= 1'b1;
                        end
                        
                        OP_COMPARE: begin
                            // Compare operation
                            // Bit 0: 1 if A > B
                            // Bit 1: 1 if A < B
                            // Nothing set (zero flag) if A = B
                            if (operand_a > operand_b) begin
                                result[7:0] <= 8'h01;  // A > B
                                flags[FLAG_ZERO] <= 1'b0;
                            end else if (operand_a < operand_b) begin
                                result[7:0] <= 8'h02;  // A < B
                                flags[FLAG_ZERO] <= 1'b0;
                            end else begin
                                result[7:0] <= 8'h00;  // A = B
                                flags[FLAG_ZERO] <= 1'b1;
                            end
                            result[15:8] <= 8'h00;
                            flags[FLAG_COMPLETE] <= 1'b1;
                        end
                        
                        default: begin
                            // Invalid opcode
                            result <= 16'h0000;
                            flags <= 4'b0000;
                        end
                    endcase
                    
                    next_state <= COMPLETE;
                end
                
                COMPLETE: begin
                    result_ready <= 1'b1;
                    if (data_valid) begin
                        // New operation is starting
                        next_state <= IDLE;
                    end else begin
                        // Hold the result until new operation starts
                        next_state <= COMPLETE;
                    end
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end
    
    // Output assignments
    assign data_out = result;
    assign data_ready = result_ready;
    assign status_flags = flags;
    
endmodule