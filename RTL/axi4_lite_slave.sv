`timescale 1ns / 1ps

module axi4_lite_slave (
    //Global Signal
    input  logic        ACLK,
    input  logic        ARESETn,
    //AW Channel
    input  logic [31:0] AWADDR,
    input  logic        AWVALID,
    output logic        AWREADY,
    //W Channel
    input  logic [31:0] WDATA,
    input  logic        WVALID,
    output logic        WREADY,
    //B Channel
    output logic [ 1:0] BRESP,
    output logic        BVALID,
    input  logic        BREADY,
    //AR Channel
    input  logic [31:0] ARADDR,
    input  logic        ARVALID,
    output logic        ARREADY,
    //R Channel
    output logic [31:0] RDATA,
    output logic        RVALID,
    input  logic        RREADY,
    output logic [ 1:0] RRESP
);

    logic [31:0] addr_reg;
    logic [31:0] mem[0:3];

    /*************************Write Transaction****************************/

    //AW Channel
    typedef enum {
        AW_IDLE,
        AW_READY
    } aw_state_e;

    aw_state_e aw_state, aw_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            aw_state <= AW_IDLE;
        end else begin
            aw_state <= aw_state_next;
        end
    end

    always_comb begin
        aw_state_next = aw_state;
        AWREADY = 0;
        case (aw_state)
            AW_IDLE: begin
                AWREADY = 1'b0;
                if (AWVALID) begin
                    aw_state_next = AW_READY;
                end
            end
            AW_READY: begin
                addr_reg      = AWADDR;
                AWREADY       = 1'b1;
                aw_state_next = AW_IDLE;  
            end
        endcase
    end

    //W Channel
    typedef enum {
        W_IDLE,
        W_READY
    } w_state_e;

    w_state_e w_state, w_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            w_state <= W_IDLE;
        end else begin
            w_state <= w_state_next;
        end
    end

    always_comb begin
        w_state_next = w_state;
        WREADY = 1'b0;
        case (w_state)
            W_IDLE: begin
                WREADY = 1'b0;
                if (WVALID) begin
                    w_state_next = W_READY;
                end
            end
            W_READY: begin
                case (addr_reg[3:2])
                    2'h0: mem[0] = WDATA;
                    2'h1: mem[1] = WDATA;
                    2'h2: mem[2] = WDATA;
                    2'h3: mem[3] = WDATA;
                endcase
                WREADY       = 1'b1;
                w_state_next = W_IDLE;
            end
        endcase
    end

    //B Channel
    typedef enum {
        B_IDLE,
        B_VALID
    } b_state_e;

    b_state_e b_state, b_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            b_state <= B_IDLE;
        end else begin
            b_state <= b_state_next;
        end
    end

    always_comb begin
        b_state_next = b_state;
        BRESP = 2'd0;
        BVALID = 1'b0;
        case (b_state)
            B_IDLE: begin
                BRESP  = 0;
                BVALID = 1'b0;
                if (WVALID & WREADY) begin
                    b_state_next = B_VALID;
                end
            end
            B_VALID: begin
                BRESP  = 0;
                BVALID = 1'b1;
                if (BVALID & BREADY) begin
                    b_state_next = B_IDLE;
                end
            end
        endcase
    end

    /*********************READ Transaction*************************/

    //AR Channel transfer
    typedef enum {
        AR_IDLE,
        AR_READY
    } ar_state_e;

    ar_state_e ar_state, ar_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            ar_state <= AR_IDLE;
        end else begin
            ar_state <= ar_state_next;
        end
    end

    always_comb begin
        ar_state_next = ar_state;
        ARREADY = 1'b0;
        case (ar_state)
            AR_IDLE: begin
                ARREADY = 1'b0;
                if (ARVALID) begin
                    ar_state_next = AR_READY;
                end
            end
            AR_READY: begin
                addr_reg = ARADDR;
                ARREADY = 1'b1;
                ar_state_next = AR_IDLE;
            end
        endcase
    end

    //R Channel transfer
    typedef enum {
        R_IDLE,
        R_VALID
    } r_state_e;

    r_state_e r_state, r_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            r_state <= R_IDLE;
        end else begin
            r_state <= r_state_next;
        end
    end

    always_comb begin
        r_state_next = r_state;
        RDATA = 0;
        RVALID = 1'b0;
        RRESP = 0;
        case (r_state)
            R_IDLE: begin
                RDATA  = 0;
                RVALID = 1'b0;
                RRESP  = 0;
                if (ARREADY) begin
                    r_state_next = R_VALID;
                end
            end
            R_VALID: begin
                RDATA  = mem[addr_reg[3:2]];
                RVALID = 1'b1;
                RRESP  = 0;
                if (RVALID & RREADY) begin
                    r_state_next = R_IDLE;
                end
            end
        endcase
    end

endmodule
