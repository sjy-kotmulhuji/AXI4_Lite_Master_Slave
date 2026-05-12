`timescale 1ns / 1ps

module tb_axi4_top ();

    //Global Signal
    logic        ACLK;
    logic        ARESETn;
    //AW Channe;
    logic [31:0] AWADDR;
    logic        AWVALID;
    logic        AWREADY;
    //W Channel
    logic [31:0] WDATA;
    logic        WVALID;
    logic        WREADY;
    //B Channe;
    logic [ 1:0] BRESP;
    logic        BVALID;
    logic        BREADY;
    //AR Channe;
    logic [31:0] ARADDR;
    logic        ARVALID;
    logic        ARREADY;
    //R Channel
    logic [31:0] RDATA;
    logic        RVALID;
    logic        RREADY;
    logic [ 1:0] RRESP;  //response 다 okay라 가정하고 무시시
    //Internal Signals
    logic        transfer;
    logic        ready;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic        write;
    logic [31:0] rdata;

    //SLAVE AXI-Lite simulator

    axi4_lite_top dut (.*);

    always #5 ACLK = ~ACLK;

    task automatic axi_write(logic [31:0] address, logic [31:0] data);
        //@(negedge ACLK);
        addr     = address;
        wdata    = data;
        write    = 1'b1;
        transfer = 1'b1;
        @(posedge ACLK);
        @(posedge ACLK);
        transfer = 1'b0;
        do @(posedge ACLK); while (!ready);  //ready 올 때까지 대기
        $display("[%0t] CPU WRITE ADDR = %0h, WDATA = %0h", $time, addr, wdata);
    endtask

    task automatic axi_read(logic [31:0] address);
        //@(negedge ACLK);
        addr     = address;
        write    = 1'b0;
        transfer = 1'b1;
        @(posedge ACLK);
        @(posedge ACLK);
        transfer = 1'b0;
        do @(posedge ACLK); while (!ready);  //ready 올 때까지 대기
        $display("[%0t] CPU READ ADDR = %0h, RDATA = %0h", $time, addr, rdata);
    endtask

    initial begin
        ACLK = 0;
        ARESETn = 0;
        repeat (3) @(posedge ACLK);
        ARESETn = 1;
        repeat (3) @(posedge ACLK);



        axi_write(32'h0000_0000, 32'h1111_1111);
        @(posedge ACLK);
        axi_write(32'h0000_0004, 32'h2222_2222);
        @(posedge ACLK);
        axi_write(32'h0000_0008, 32'h3333_3333);
        @(posedge ACLK);
        axi_write(32'h0000_000c, 32'h4444_4444);

        @(posedge ACLK);

        axi_read(32'h0000_0000);
        @(posedge ACLK);
        axi_read(32'h0000_0004);
        @(posedge ACLK);
        axi_read(32'h0000_0008);
        @(posedge ACLK);
        axi_read(32'h0000_000c);

        repeat (10) @(posedge ACLK);
        $finish;
    end

endmodule

