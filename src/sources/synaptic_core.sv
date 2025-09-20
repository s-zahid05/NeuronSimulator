//Author: Sadeem Zahid

module synaptic_core #(
    parameter int N_SYNAPSES    = 8192,
    parameter int WEIGHT_WIDTH  = 16,
    parameter int TRACE_WIDTH   = 18,
    parameter int TAU_PLUS      = 64,
    parameter int TAU_MINUS     = 32,
    parameter int A2_PLUS_SH    = 6,
    parameter int A2_MINUS_SH   = 4,
    parameter int MAX_WEIGHT    = 1000,
    parameter int MIN_WEIGHT    = 0,
    parameter int U_BASE        = 32,   
    parameter int R_TARGET      = 256, 
    parameter int U_SCALE_SHIFT = 9,
    parameter string WEIGHT_MEM_FILE = "weights.mem",
    parameter string R1_MEM_FILE     = "r1_traces.mem",
    parameter string O1_MEM_FILE     = "o1_traces.mem",
    parameter bit INIT_FROM_FILE     = 1'b1
)(
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         enable_learning,
    input  logic                         pre_spike,
    input  logic                         post_spike,
    input  logic [$clog2(N_SYNAPSES)-1:0] syn_addr,
    input  logic                         syn_cs,
    input  logic                         syn_we,
    output logic signed [WEIGHT_WIDTH-1:0] weight_out,
    output logic signed [WEIGHT_WIDTH-1:0] efficacy_out
);

    // Cycle counter since last learning event
    logic [31:0] clk_counter;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk_counter <= 0;
        else if (enable_learning && (pre_edge || post_edge))
            clk_counter <= 0;
        else
            clk_counter <= clk_counter + 1;
    end

    // Edge detection for pre and post spikes
    logic pre_spike_reg, post_spike_reg;
    logic pre_edge, post_edge;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pre_spike_reg  <= 1'b0;
            post_spike_reg <= 1'b0;
        end else begin
            pre_spike_reg  <= pre_spike;
            post_spike_reg <= post_spike;
        end
    end
    assign pre_edge  = pre_spike  & ~pre_spike_reg;
    assign post_edge = post_spike & ~post_spike_reg;

    // Memory arrays for STDP & STP traces and weights
    logic signed [TRACE_WIDTH-1:0] r1_mem [N_SYNAPSES-1:0];
    logic signed [TRACE_WIDTH-1:0] o1_mem [N_SYNAPSES-1:0];
    logic signed [TRACE_WIDTH-1:0] R_mem  [N_SYNAPSES-1:0];
    logic signed [TRACE_WIDTH-1:0] u_mem  [N_SYNAPSES-1:0];
    logic signed [WEIGHT_WIDTH-1:0] weight_mem [N_SYNAPSES-1:0];
    
    //For simulation
    initial begin
        if (INIT_FROM_FILE) begin
            if (WEIGHT_MEM_FILE != "") $readmemh(WEIGHT_MEM_FILE, weight_mem);
            else for (int i=0; i<N_SYNAPSES; i++) weight_mem[i] = 0;
            
            if (R1_MEM_FILE     != "") $readmemh(R1_MEM_FILE,     r1_mem);
            else for (int i=0; i<N_SYNAPSES; i++) r1_mem[i]     = 0;
            
            if (O1_MEM_FILE     != "") $readmemh(O1_MEM_FILE,     o1_mem);
            else for (int i=0; i<N_SYNAPSES; i++) o1_mem[i]     = 0;
            
            for (int i=0; i<N_SYNAPSES; i++) begin
                R_mem[i] = R_TARGET; 
                u_mem[i] = U_BASE;   
            end
        end else begin
            for (int i=0; i<N_SYNAPSES; i++) begin
                weight_mem[i] = 0;
                r1_mem[i]     = 0;
                o1_mem[i]     = 0;
                R_mem[i]      = R_TARGET; 
                u_mem[i]      = U_BASE;
            end
        end
    end

    // Read current values
    logic signed [TRACE_WIDTH-1:0] r1_raw, o1_raw, R_raw, u_raw;
    logic signed [WEIGHT_WIDTH-1:0] weight_current;
    always_comb begin
        r1_raw         = r1_mem[syn_addr];
        o1_raw         = o1_mem[syn_addr];
        R_raw          = R_mem[syn_addr];
        u_raw          = u_mem[syn_addr];
        weight_current = weight_mem[syn_addr];
        
    end

    // Compute decay shifts in core
    localparam int TAU_PLUS_SHIFT  = $clog2(TAU_PLUS);
    localparam int TAU_MINUS_SHIFT = $clog2(TAU_MINUS);
    int delta_log2, decay_shift_plus, decay_shift_minus;
    logic signed [TRACE_WIDTH-1:0] r1_decayed, o1_decayed, R_decayed, u_decayed;
    always_comb begin
        if (clk_counter <= 1) begin
            r1_decayed = r1_raw;
            o1_decayed = o1_raw;
            R_decayed  = R_raw;
            u_decayed  = u_raw;
        end else begin
            delta_log2 = $clog2(clk_counter);
            decay_shift_plus  = (delta_log2 < TAU_PLUS_SHIFT)  ? (TAU_PLUS_SHIFT - delta_log2)   : 0;
            decay_shift_minus = (delta_log2 < TAU_MINUS_SHIFT) ? (TAU_MINUS_SHIFT - delta_log2) : 0;
    
            // Apply hybrid linear decay
            if (r1_raw > 0) begin
                r1_decayed = r1_raw - ((r1_raw >>> decay_shift_plus) | 1);
            end else begin
                r1_decayed = r1_raw;
            end
    
            if (o1_raw > 0) begin
                o1_decayed = o1_raw - ((o1_raw >>> decay_shift_minus) | 1);
            end else begin
                o1_decayed = o1_raw;
            end
    
            // STP: recover R towards R_TARGET and u toward U_BASE
            if (R_raw < R_TARGET)
                R_decayed = R_raw + ((R_TARGET - R_raw) >>> (decay_shift_minus + 1));
            else
                R_decayed = R_raw;
    
            if (u_raw != U_BASE)
                u_decayed = u_raw + ((U_BASE - u_raw) >>> (decay_shift_plus + 1));
            else
                u_decayed = u_raw;
        end
    end

    // STDP update instance
    logic stdp_trigger;
    logic signed [TRACE_WIDTH-1:0] r1_new, o1_new;
    logic signed [WEIGHT_WIDTH-1:0] weight_new;
    stdp_update #(
        .TRACE_WIDTH(TRACE_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .TAU_PLUS(TAU_PLUS),
        .TAU_MINUS(TAU_MINUS),
        .A2_PLUS_SH(A2_PLUS_SH),
        .A2_MINUS_SH(A2_MINUS_SH),
        .MAX_WEIGHT(MAX_WEIGHT),
        .MIN_WEIGHT(MIN_WEIGHT)
    ) stdp_inst (
        .enable                 (enable_learning),
        .stdp_update_trigger    (stdp_trigger),
        .pre_spike_edge         (pre_edge),
        .post_spike_edge        (post_edge),
        .weight_in              (weight_current),
        .r1_in                  (r1_decayed),
        .o1_in                  (o1_decayed),
        .weight_out             (weight_new),
        .r1_out                 (r1_new),
        .o1_out                 (o1_new)
    );
    
    logic signed [TRACE_WIDTH-1:0] u_updated, R_updated;
    logic signed [WEIGHT_WIDTH-1:0] efficacy_stp;
    
    STP #(
        .DATA_WIDTH(TRACE_WIDTH),      
        .WEIGHT_WIDTH(WEIGHT_WIDTH),   
        .U_BASE(U_BASE),
        .U_SCALE_SHIFT(U_SCALE_SHIFT),
        .R_TARGET(R_TARGET)
    ) stp_inst (
        .pre_spike  (pre_edge),
        .u_decayed  (u_decayed),
        .R_decayed  (R_decayed),
        .weight     (weight_current),  
        .u_out      (u_updated),
        .R_out      (R_updated),
        .efficacy   (efficacy_stp)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
        end else if (syn_cs) begin  // Only update when chip select is active
            // Always store decayed values first
            r1_mem[syn_addr] <= r1_decayed;
            o1_mem[syn_addr] <= o1_decayed;
            R_mem[syn_addr]  <= R_decayed;
            u_mem[syn_addr]  <= u_decayed;
            
            // Override with STDP updates if triggered
            if (stdp_trigger) begin
                r1_mem[syn_addr]     <= r1_new;
                o1_mem[syn_addr]     <= o1_new;
                weight_mem[syn_addr] <= weight_new;
            end
            
            // Override with STP updates if pre-spike
            if (pre_edge) begin
                R_mem[syn_addr] <= R_updated;
                u_mem[syn_addr] <= u_updated;
            end
        end
    end

    assign weight_out   = weight_current;
    assign efficacy_out = efficacy_stp;
    assign stdp_trigger = enable_learning && (pre_edge || post_edge);

endmodule