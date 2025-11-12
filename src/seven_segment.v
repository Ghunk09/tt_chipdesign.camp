// This module drives a 7-segment display.
// It takes a 4-bit number and outputs the corresponding 7-segment display code.

module seven_segment (
    input  wire clk,
    input  wire rst_n,
    input  wire [3:0] data,
    output reg  [7:0] segments
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            segments <= 8'b00000000;
        end else begin
            case (data)
                4'h0: segments <= 8'b11111100; // 0
                4'h1: segments <= 8'b01100000; // 1
                4'h2: segments <= 8'b11011010; // 2
                4'h3: segments <= 8'b11110010; // 3
                4'h4: segments <= 8'b01100110; // 4
                4'h5: segments <= 8'b10110110; // 5
                4'h6: segments <= 8'b10111110; // 6
                4'h7: segments <= 8'b11100000; // 7
                4'h8: segments <= 8'b11111110; // 8
                4'h9: segments <= 8'b11110110; // 9
                4'ha: segments <= 8'b11101110; // A
                4'hb: segments <= 8'b00111110; // b
                4'hc: segments <= 8'b10011100; // C
                4'hd: segments <= 8'b01111010; // d
                4'he: segments <= 8'b10011110; // E
                4'hf: segments <= 8'b10001110; // F
                default: segments <= 8'b00000000; // Off
            endcase
        end
    end

endmodule
