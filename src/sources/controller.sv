//Author: Sadeem Zahid

//controller heavily based off of ODIN controller file 
//Frenkel, C. (2019). ODIN: online-learning digital spiking neural network (SNN) processor (HDL source code and documentation) 
//[Computer software]. GitHub. https://github.com/ChFrenkel/ODIN

module controller #(
    parameter int N = 256,
    parameter int M = 8
)(
    // Global inputs
    input  logic           CLK,
    input  logic           RST,

    // AER input interface
    input  logic   [2*M:0] AERIN_ADDR,
    input  logic           AERIN_REQ,
    output logic           AERIN_ACK,

    // Scheduler interface
    input  logic           SCHED_EMPTY,
    input  logic           SCHED_FULL,
    input  logic           SCHED_BURST_END,
    input  logic    [12:0] SCHED_DATA_OUT,

    // AER output busy flag
    input  logic           AEROUT_CTRL_BUSY,

    // Outputs to synaptic core
    output logic    [M-1:0] CTRL_PRE_EN,
    output logic            CTRL_BIST_REF,
    output logic            CTRL_SYN_CS,
    output logic            CTRL_SYN_WE,
    output logic    [12:0]  CTRL_SYN_ADDR,

    // Outputs to neuron core
    output logic            CTRL_NEUR_EVENT,
    output logic            CTRL_NEUR_TREF,
    output logic    [4:0]   CTRL_NEUR_PARAM,

    // Outputs to scheduler
    output logic            CTRL_SCHED_POP_N,
    output logic    [M-1:0] CTRL_SCHED_ADDR,
    output logic    [6:0]   CTRL_SCHED_EVENT_IN,
    output logic    [4:0]   CTRL_SCHED_PARAM,

    // AER output interface
    output logic           CTRL_AEROUT_POP_NEUR
);

    // FSM state enumeration
    typedef enum logic [2:0] {
        WAIT     = 3'd0,
        SYNAPSE  = 3'd1,
        TREF     = 3'd2,
        PUSH     = 3'd3,
        POP_NEUR = 3'd4,
        POP_VIRT = 3'd5
    } state_t;

    state_t state, nextstate;
    logic [M-1:0] neur_cnt;

    // Event type decode logic
    logic syn_event, tref_event, virt_event;
    
    assign syn_event  = AERIN_ADDR[2*M];
    assign tref_event = !syn_event && &AERIN_ADDR[M-2:0];
    assign virt_event = !syn_event && (AERIN_ADDR[2:0] == 3'b001);

    // State register
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            state <= WAIT;
        end else begin
            state <= nextstate;
        end
    end

    // Next-state logic
    always_comb begin
        nextstate = WAIT;
        
        case (state)
            WAIT: begin
                if (!AEROUT_CTRL_BUSY && AERIN_REQ) begin
                    if (tref_event) begin
                        nextstate = TREF;
                    end else if (syn_event) begin
                        nextstate = SYNAPSE;
                    end else if (virt_event) begin
                        nextstate = PUSH;
                    end else begin
                        nextstate = WAIT;
                    end
                end else if (!SCHED_EMPTY) begin
                    if (|SCHED_DATA_OUT[12:8]) begin
                        nextstate = POP_VIRT;
                    end else begin
                        nextstate = POP_NEUR;
                    end
                end
            end
            
            SYNAPSE, TREF, PUSH, POP_NEUR, POP_VIRT: begin
                nextstate = WAIT;
            end
            
            default: begin
                nextstate = WAIT;
            end
        endcase
    end

    // Neuron counter for POP_NEUR loops
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            neur_cnt <= '0;
        end else if (state == WAIT) begin
            neur_cnt <= '0;
        end else if (state == POP_NEUR) begin
            neur_cnt <= neur_cnt + 1'b1;
        end
    end

    // AER output control
    assign CTRL_AEROUT_POP_NEUR = (state == POP_NEUR) && (neur_cnt == CTRL_SCHED_ADDR);

    // Output control signals
    always_comb begin
        // Default assignments
        CTRL_PRE_EN         = '0;
        CTRL_BIST_REF       = '0;
        CTRL_SYN_CS         = '0;
        CTRL_SYN_WE         = '0;
        CTRL_SYN_ADDR       = '0;

        CTRL_NEUR_EVENT     = '0;
        CTRL_NEUR_TREF      = '0;
        CTRL_NEUR_PARAM     = '0;

        CTRL_SCHED_POP_N    = '1;
        CTRL_SCHED_ADDR     = '0;
        CTRL_SCHED_EVENT_IN = '0;
        CTRL_SCHED_PARAM    = '0;

        AERIN_ACK           = '0;

        case (state)
            SYNAPSE: begin
                CTRL_NEUR_EVENT = '1;
                CTRL_SYN_ADDR   = AERIN_ADDR[2*M-1:M];
                CTRL_SYN_CS     = '1;
                CTRL_SYN_WE     = '1;
                CTRL_PRE_EN     = {{(M-3){1'b0}}, AERIN_ADDR[2:0]};
            end
            
            TREF: begin
                CTRL_NEUR_EVENT = '1;
                CTRL_NEUR_TREF  = '1;
            end
            
            PUSH: begin
                CTRL_SCHED_EVENT_IN = 7'h40;
                CTRL_SCHED_ADDR     = AERIN_ADDR[2*M-1:M];
                CTRL_SCHED_PARAM    = AERIN_ADDR[M-1:0];
                CTRL_SCHED_POP_N    = '0;
            end
            
            POP_NEUR: begin
                CTRL_SYN_CS     = (neur_cnt[2:0] == '0);
                CTRL_SYN_WE     = (neur_cnt[2:0] == '0);
                CTRL_PRE_EN     = '1; // all ones
                CTRL_NEUR_EVENT = '1;
            end
            
            POP_VIRT: begin
                CTRL_NEUR_EVENT  = '1;
                CTRL_NEUR_PARAM  = SCHED_DATA_OUT[12:8];
                CTRL_SCHED_POP_N = '0;
            end
            
            WAIT: begin
                if (AERIN_REQ) begin
                    AERIN_ACK = '1;
                end
            end
            
            default: begin
            end
        endcase
    end

endmodule