`timescale 1ns / 1ps

module axi4_lite_top (
    input  logic        ACLK,
    input  logic        ARESETn,
    input  logic        transfer,
    output logic        ready,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic        write,
    output logic [31:0] rdata
);

    //AW Channel
    logic [31:0] AWADDR;
    logic        AWVALID;
    logic        AWREADY;
    //W Channel
    logic [31:0] WDATA;
    logic        WVALID;
    logic        WREADY;
    //B Channel
    logic [ 1:0] BRESP;
    logic        BVALID;
    logic        BREADY;
    //AR Channel
    logic [31:0] ARADDR;
    logic        ARVALID;
    logic        ARREADY;
    //R Channel
    logic [31:0] RDATA;
    logic        RVALID;
    logic        RREADY;
    logic [ 1:0] RRESP;

    axi4_lite_master U_AXI4_M (.*);
    axi4_lite_slave U_AXI4_S (.*);



endmodule
