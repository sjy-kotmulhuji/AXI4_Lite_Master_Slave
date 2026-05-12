`timescale 1ns / 1ps

module tb_axi4_lite ();

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
    logic [31:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;

    axi4_lite_master dut (.*);

    always #5 ACLK = ~ACLK;

    bit [31:0] slave_addr;
    bit slv_addr_flag;

    task automatic axi_slave_write_aw();
        //AW Channel
        forever begin
            @(posedge ACLK);
            if (AWVALID & !AWREADY) begin
                slave_addr = AWADDR;
                AWREADY    = 1'b1;
                slv_addr_flag = 1;
            end else if (AWVALID & AWREADY) begin
                AWREADY = 1'b0;
            end else begin
                AWREADY = 1'b0;
                slv_addr_flag = 0;
            end
        end
    endtask

    task automatic axi_slave_write_w();
        //W Channel
        forever begin
            @(posedge ACLK);
            if (WVALID & !WREADY) begin
                wait (slv_addr_flag);
                case (slave_addr[3:2])
                    2'h0: slv_reg0 = WDATA;
                    2'h1: slv_reg1 = WDATA;
                    2'h2: slv_reg2 = WDATA;
                    2'h3: slv_reg3 = WDATA;
                endcase
                WREADY = 1'b1;
                $display("[%0t] SLAVE WRITE ADDR = %0h, WDATA = %0h", $time,
                         slave_addr, WDATA);
            end else if (WVALID & WREADY) begin
                WREADY = 1'b0;
            end else begin
                WREADY = 1'b0;
            end
        end
    endtask

    task automatic axi_slave_write_b();
        //W Channel
        forever begin
            @(posedge ACLK);
            if (WVALID) begin
                BRESP  = 2'b00; //항상 okay로 고정시켜 놓음
                BVALID = 1'b1;  //항상 1로 고정시켜 놓음. 둘 다 slave에서 받아야 함
                $display("[%0t] SLAVE WRITE BRESP = %0h", $time, BRESP);
            end else if (BVALID & BREADY) begin
                BVALID = 1'b0;
            end else begin
                BVALID = 1'b0;
            end
        end
    endtask

    task automatic axi_slave_read_ar();
        //W Channel
        forever begin
            @(posedge ACLK);
            if (ARVALID & !ARREADY) begin
                slave_addr = ARADDR;
                ARREADY = 1'b1;
                slv_addr_flag = 1;
                $display("[%0t] SLAVE WRITE ADDR = %0h", $time, slave_addr);
            end else if (ARVALID & ARREADY) begin
                ARREADY = 1'b0;
                slv_addr_flag = 1;
            end else begin
                ARREADY = 1'b0;
                slv_addr_flag = 0;
            end
        end
    endtask

    task automatic axi_slave_read_r();
        //W Channel
        forever begin
            @(posedge ACLK);
            if (!RVALID & ARVALID) begin
                wait (slv_addr_flag);
                case (slave_addr[3:2])
                    2'h0: RDATA = slv_reg0;
                    2'h1: RDATA = slv_reg1;
                    2'h2: RDATA = slv_reg2;
                    2'h3: RDATA = slv_reg3;
                endcase
                RVALID = 1'b1;
                RRESP  = 2'b00;
                $display("[%0t] SLAVE READ ADDR = %0h, WDATA = %0h", $time,
                         slave_addr, RDATA);
            end else if (RVALID & RREADY) begin
                RVALID = 1'b0;
            end else begin
                RVALID = 1'b0;
                RRESP  = 2'b00;
            end
        end
    endtask

    task automatic axi_write(logic [31:0] address, logic [31:0] data);
        addr     <= address;
        wdata    <= data;
        write    <= 1'b1;
        transfer <= 1'b1;
        @(posedge ACLK);
        transfer <= 1'b0;
        do @(posedge ACLK); while (!ready);  //ready 올 때까지 대기
        $display("[%0t] CPU WRITE ADDR = %0h, WDATA = %0h", $time, addr, wdata);
    endtask

    task automatic axi_read(logic [31:0] address);
        addr     <= address;
        write    <= 1'b0;
        transfer <= 1'b1;
        @(posedge ACLK);
        transfer <= 1'b0;
        do @(posedge ACLK); while (!ready);  //ready 올 때까지 대기
        $display("[%0t] CPU READ ADDR = %0h, RDATA = %0h", $time, addr, rdata);
    endtask

    initial begin
        ACLK = 0;
        ARESETn = 0;
        repeat (3) @(posedge ACLK);
        ARESETn = 1;
        repeat (3) @(posedge ACLK);

        fork
            axi_slave_write_aw();
            axi_slave_write_w();
            axi_slave_write_b();
            axi_slave_read_ar();
            axi_slave_read_r();
        join_none  //프로세스 완료 기다리지 않고 바로 다음 문장 실행 왜냐 다 forever이므로

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
