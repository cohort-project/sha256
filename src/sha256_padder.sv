// import sha256_pkg::*;

module sha256_padder #(
    parameter int unsigned SHA_IF_DATA_W   = 256
    ,parameter int unsigned SHA_IF_BYTES   = 256/8
    ,parameter int unsigned SHA_IF_BYTES_W = $clog2(SHA_IF_BYTES)
    ,parameter int unsigned SHA_IF_BITS_W  = $clog2(256)
)(
     input clk
    ,input rst
    
    ,input  logic                           src_padder_data_val                   
    ,input  logic   [SHA_IF_DATA_W-1:0]     src_padder_data
    ,input  logic   [SHA_IF_BYTES_W-1:0]    src_padder_data_padbytes
    ,input  logic                           src_padder_data_last
    ,output logic                           padder_src_rdy
    
    ,output logic                           padder_dst_data_val                   
    ,output logic   [SHA_IF_DATA_W-1:0]     padder_dst_data
    ,output logic                           padder_dst_data_last
    ,input  logic                           dst_padder_data_rdy
);

    // this is the minimum bytes needed to contain the 1 bit padded to a whole
    // byte and the 8-byte length
    localparam OVERFLOW_PADBYTES = 9;

    typedef enum logic[2:0] {
        READY = 3'd0,
        UPPER  = 3'd1,
        LOWER = 3'd2,
        UPPER_PAD_ONE = 3'd3,
        UPPER_PAD_ZEROS = 3'd4,
        LOWER_PAD_ONE = 3'd5,
        LOWER_PAD_ZEROS = 3'd6,
        UND = 'X
    } state_e;

    typedef enum logic[1:0] {
        INPUT = 2'd0,
        PAD_ONES_DATA = 2'd1,
        PAD_ONES_ONLY = 2'd2,
        PAD_ZEROES = 2'd3
    } pad_data_mux_sel_e;

    state_e state_reg;
    state_e state_next;

    logic   output_length;

    logic   [SHA_IF_DATA_W-1:0]    pad_base_one;
    logic   [SHA_IF_DATA_W-1:0]    pad_base_one_shifted;

    logic   [63:0]  length_reg;
    logic   [63:0]  length_next;
    logic           incr_length;
    logic           init_metadata;

    logic                       data_val_reg;
    logic                       data_val_next;

    logic   [SHA_IF_DATA_W-1:0] data_reg;
    logic   [SHA_IF_DATA_W-1:0] data_next;

    logic   [SHA_IF_BYTES_W-1:0]    padbytes_reg;
    logic   [SHA_IF_BYTES_W-1:0]    padbytes_next;

    logic   [SHA_IF_BITS_W-1:0] pad_base_one_shift;

    pad_data_mux_sel_e          pad_data_mux_sel;
    logic   [SHA_IF_DATA_W-1:0] pad_data_mux_out;

    logic   store_data;

    assign pad_base_one_shift = (SHA_IF_BYTES - padbytes_reg) << 3;

    assign pad_base_one = {1'b1, {(SHA_IF_DATA_W-1){1'b0}}};
    assign pad_base_one_shifted = pad_base_one >> pad_base_one_shift;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY; 
            data_reg <= '0;
            padbytes_reg <= '0;
            length_reg <= '0;
            data_val_reg <= '0;
        end
        else begin
            state_reg <= state_next; 
            data_reg <= data_next;
            padbytes_reg <= padbytes_next;
            length_reg <= length_next;
            data_val_reg <= data_val_next;
        end
    end

    always_comb begin
        padder_src_rdy = 1'b0;
        padder_dst_data_val = 1'b0;
        padder_dst_data_last = 1'b0;

        init_metadata = 1'b0;
        incr_length = 1'b0;
        store_data = 1'b0;

        pad_data_mux_sel = INPUT;
        output_length = 1'b0;

        data_val_next = data_val_reg;
        state_next = state_reg;
        case (state_reg)
            READY: begin
                padder_src_rdy = 1'b1;
                init_metadata = 1'b1;
                if (src_padder_data_val) begin
                    incr_length = 1'b1;
                    store_data = 1'b1;
                    data_val_next = 1'b1;
                    if (src_padder_data_last) begin
                        if (src_padder_data_padbytes == 0) begin
                            state_next = LOWER_PAD_ONE; 
                        end
                        else begin
                            state_next = UPPER_PAD_ONE;
                        end
                    end
                    else begin
                        state_next = UPPER; 
                    end
                end
                else begin
                    state_next = READY;
                end
            end
            UPPER: begin
                padder_dst_data_val = src_padder_data_val; 
                padder_src_rdy = dst_padder_data_rdy;
                if (src_padder_data_val & dst_padder_data_rdy) begin
                    store_data = 1'b1;
                    incr_length = 1'b1;
                    if (src_padder_data_last) begin
                        if (src_padder_data_padbytes == 0) begin
                            state_next = LOWER_PAD_ONE; 
                        end
                        else begin
                            state_next = UPPER_PAD_ONE; 
                        end
                    end
                    else begin
                        state_next = LOWER;
                    end
                end
                else begin
                    state_next = UPPER; 
                end
            end
            LOWER: begin
                padder_dst_data_val = src_padder_data_val;
                padder_src_rdy = dst_padder_data_rdy;

                if (src_padder_data_val & dst_padder_data_rdy) begin
                    store_data = 1'b1;
                    incr_length = 1'b1;

                    if (src_padder_data_last) begin
                        if (src_padder_data_padbytes == 0) begin
                            state_next = UPPER_PAD_ONE; 
                        end
                        else begin
                            state_next = LOWER_PAD_ONE; 
                        end
                    end
                    else begin
                        state_next = LOWER; 
                    end
                end
                else begin
                    state_next = LOWER; 
                end
            end
            UPPER_PAD_ONE: begin
                padder_dst_data_val = 1'b1;
                pad_data_mux_sel = data_val_reg
                                ? PAD_ONES_DATA
                                : PAD_ONES_ONLY;
                if (dst_padder_data_rdy) begin
                    data_val_next = 1'b0;
                    state_next = LOWER_PAD_ZEROS;        
                end
                else begin
                    state_next = UPPER_PAD_ONE; 
                end
            end
            UPPER_PAD_ZEROS: begin
                padder_dst_data_val = 1'b1;
                pad_data_mux_sel = PAD_ZEROES;
                if (dst_padder_data_rdy) begin
                    state_next = LOWER_PAD_ZEROS;        
                end
                else begin
                    state_next = UPPER_PAD_ZEROS; 
                end
            end
            LOWER_PAD_ONE: begin
                padder_dst_data_val = 1'b1;
                output_length = padbytes_reg >= OVERFLOW_PADBYTES;
                padder_dst_data_last = padbytes_reg >= OVERFLOW_PADBYTES;

                if (dst_padder_data_rdy) begin
                    data_val_next = 1'b0;
                    // if we can output the length and minimum 1 padbyte
                    if (padbytes_reg >= OVERFLOW_PADBYTES) begin
                        pad_data_mux_sel = PAD_ONES_DATA; 
                        state_next = READY; 
                    end
                    // in the case, we actually have no space to pad in this
                    // line, we have to throw back to the upper half of the
                    // block
                    else if (padbytes_reg == 0) begin
                        pad_data_mux_sel = INPUT;         
                        state_next = UPPER_PAD_ONE;
                    end
                    else begin
                        pad_data_mux_sel = PAD_ONES_DATA;
                        state_next = UPPER_PAD_ZEROS;
                    end
                end
                else begin
                    state_next = LOWER_PAD_ONE;    
                end
            end
            LOWER_PAD_ZEROS: begin
                padder_dst_data_val = 1'b1;
                pad_data_mux_sel = PAD_ZEROES;
                output_length = 1'b1;
                padder_dst_data_last = 1'b1;

                if (dst_padder_data_rdy) begin
                    state_next = READY;  
                end
                else begin
                    state_next = LOWER_PAD_ZEROS; 
                end
            end
            default: begin
                padder_src_rdy = 'X;
                padder_dst_data_val = 'X;
                padder_dst_data_last = 'X;

                init_metadata = 'X;
                incr_length = 'X;
                store_data = 'X;
                data_val_next = 'X;

                output_length = 'X;
                
                pad_data_mux_sel = INPUT;

                state_next = UND;
            end
        endcase
    end

    logic   [63:0] num_bits;

    assign num_bits = (SHA_IF_BYTES - src_padder_data_padbytes) << 3;
    always_comb begin
        if (init_metadata & incr_length) begin
            if (src_padder_data_last) begin
                length_next = (SHA_IF_BYTES - src_padder_data_padbytes) << 3; 
            end
            else begin
                length_next = SHA_IF_DATA_W;
            end
        end
        else if (init_metadata) begin
            length_next = '0;
        end
        else if (incr_length) begin
            if (src_padder_data_last) begin
                length_next = length_reg + 
                                ((SHA_IF_BYTES - src_padder_data_padbytes) << 3); 
            end
            else begin
                length_next = length_reg + SHA_IF_DATA_W;
            end
        end
        else begin
            length_next = length_reg;
        end
    end

    logic   [SHA_IF_DATA_W-1:0] masked_data;

    data_masker #(
         .width_p   (SHA_IF_DATA_W)
    ) input_masker (  
         .unmasked_data (src_padder_data            )
        ,.padbytes      (src_padder_data_padbytes   )
        ,.last          (src_padder_data_last       )

        ,.masked_data   (masked_data                )
    );

    assign data_next = store_data
                        ? masked_data
                        : data_reg;

    assign padbytes_next = store_data
                            ? src_padder_data_padbytes
                            : padbytes_reg;

    // we can just or in the things, because we know the bits
    // are already zero
    always_comb begin
        if (pad_data_mux_sel == PAD_ONES_DATA) begin
            pad_data_mux_out = data_reg | pad_base_one_shifted;
        end
        else if (pad_data_mux_sel == PAD_ONES_ONLY) begin
            pad_data_mux_out = pad_base_one_shifted;
        end
        else if (pad_data_mux_sel == PAD_ZEROES) begin
            pad_data_mux_out = '0; 
        end
        else begin
            pad_data_mux_out = data_reg;
        end
    end

    always_comb begin
        if (output_length) begin
            padder_dst_data = {pad_data_mux_out[SHA_IF_DATA_W-1:64], length_reg};
        end
        else begin
            padder_dst_data = pad_data_mux_out; 
        end
    end


endmodule
