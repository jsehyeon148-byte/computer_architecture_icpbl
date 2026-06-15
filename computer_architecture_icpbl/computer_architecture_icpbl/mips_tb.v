`timescale 1ns / 1ps

module mips_tb;
    reg         clk;
    reg         rst_n;

    // IO Ports
    reg  [7:0]  switches;
    wire [7:0]  led;
    wire        pwm_out;

    // Debug Monitoring
    wire [31:0] pc_out;
    wire [31:0] alu_result;

    // Unit Under Test (UUT)
    mips uut (
        .clk(clk),
        .rst_n(rst_n),
        .switches(switches),
        .pwm_out(pwm_out),
        .pc_out(pc_out),
        .alu_result(alu_result),
        .led(led)
    );

    // Clock Generation: 10ns period = 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Trace Generation
    initial begin
        $dumpfile("mips.vcd");
        $dumpvars(0, mips_tb);
    end

    // Monitor LED changes to show duty cycle tracking
    reg [7:0] last_led;
    initial last_led = 8'hFF;
    always @(posedge clk) begin
        if (led !== last_led) begin
            $display("[%0t ns] PWM duty/LED: %0d -> %0d  (target switches=%0d)",
                     $time, last_led, led, switches);
            last_led <= led;
        end
    end

    // Simulation Control
    initial begin
        rst_n    = 0;
        switches = 8'h00;

        #15;
        rst_n = 1;

        $display("===========================================");
        $display("   MIPS Class 13: Final Demo Simulation   ");
        $display("===========================================");
        $display("[%0t ns] Reset released. CPU starting...", $time);

        // Phase 1: Idle
        $display("[%0t ns] Phase 1: Idle (switches=0x00)", $time);
        #20000;

        // Phase 2: Accelerate
        $display("[%0t ns] Phase 2: Accelerate (switches=0x80 = 128)", $time);
        switches = 8'h80;
        #80000;

        // Phase 3: Decelerate
        $display("[%0t ns] Phase 3: Decelerate (switches=0x20 = 32)", $time);
        switches = 8'h20;
        #80000;

        // Phase 4: Accelerate again
        $display("[%0t ns] Phase 4: Accelerate (switches=0xFF = 255)", $time);
        switches = 8'hFF;
        #100000;

        $display("===========================================");
        $display("   Simulation Complete                     ");
        $display("===========================================");
        $finish;
    end

endmodule
