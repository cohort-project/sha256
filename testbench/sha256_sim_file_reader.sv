`include "sha256_defs.svh"
module sha256_sim_file_reader (
     input clk
    ,input rst

    ,output logic                           file_dst_data_val                   
    ,output logic   [SHA_IF_DATA_W-1:0]     file_dst_data
    ,output logic                           file_dst_data_last
    ,input  logic                           dst_file_rdy

    ,input  logic                           src_file_digest_val
    ,input  logic   [SHA256_DIGEST_W-1:0]   src_file_digest
    ,output logic                           file_src_digest_rdy
);

    typedef struct packed {
        logic   [SHA_IF_DATA_W-1:0] data;
        logic                       last;
    } queue_entry_struct;
    localparam QUEUE_ENTRY_STRUCT_W = SHA_IF_DATA_W + 1;

    logic   [SHA_IF_DATA_W-1:0] data_dpi;
    logic   [SHA_IF_DATA_W-1:0] data_dpi_reg;
    
    logic   [SHA_IF_DATA_W-1:0] data_last_dpi;
    logic   [SHA_IF_DATA_W-1:0] data_last_dpi_reg;

    logic                       data_val_dpi;
    logic                       data_val_dpi_reg;

    logic                       data_fifo_rdy;
    queue_entry_struct          data_fifo_wr_data;

    queue_entry_struct          data_fifo_rd_data;

    always_ff @(posedge clk) begin
        if (rst) begin
            data_dpi_reg <= '0;
            data_last_dpi_reg <= '0;
            data_val_dpi_reg <= '0;
        end 
        else begin
            data_dpi_reg <= data_dpi;
            data_last_dpi_reg <= data_last_dpi;
            data_val_dpi_reg <= data_val_dpi;
        end       
    end

/* *************************************************************************
* Input
* *************************************************************************/

    import "DPI-C" context function void get_input_data();
    always @(negedge clk) begin
        if (data_fifo_rdy & ~rst) begin
            get_input_data();
        end 
    end

    export "DPI-C" function drive_input_if;
    function void drive_input_if(input bit val,
                                 input bit[SHA_IF_DATA_W-1:0] data,
                                 input bit last);
        data_dpi = data;
        data_val_dpi = val;
        data_last_dpi = last;
    endfunction

    assign data_fifo_wr_data.data = data_dpi_reg;
    assign data_fifo_wr_data.last = data_last_dpi_reg;
    
    bsg_fifo_1r1w_small #( 
         .width_p   (QUEUE_ENTRY_STRUCT_W)
        ,.els_p     (32)
    ) data_fifo (
         .clk_i     (clk)
        ,.reset_i   (rst)

        ,.v_i       (data_val_dpi_reg   )
        ,.ready_o   (data_fifo_rdy      )
        ,.data_i    (data_fifo_wr_data  )

        ,.v_o       (file_dst_data_val  )
        ,.data_o    (data_fifo_rd_data  )
        ,.yumi_i    (dst_file_rdy & file_dst_data_val )
    );
    assign file_dst_data = data_fifo_rd_data.data;
    assign file_dst_data_last = data_fifo_rd_data.last;
/* *************************************************************************
* Output
* *************************************************************************/

    logic                           digest_fifo_rd_val;
    logic   [SHA256_DIGEST_W-1:0]   digest_fifo_rd_data;
    logic                           digest_fifo_rd_rdy;
        bsg_fifo_1r1w_small #( 
             .width_p   (SHA256_DIGEST_W    )
            ,.els_p     (32)
        ) digest_fifo (
             .clk_i     (clk)
            ,.reset_i   (rst)

            ,.v_i       (src_file_digest_val      )
            ,.ready_o   (file_src_digest_rdy        )
            ,.data_i    (src_file_digest            )

            ,.v_o       (digest_fifo_rd_val         )
            ,.data_o    (digest_fifo_rd_data        )
            ,.yumi_i    (digest_fifo_rd_rdy & digest_fifo_rd_val    )
        );

        assign digest_fifo_rd_rdy = 1'b1;

    import "DPI-C" context function void put_digest(input bit[SHA256_DIGEST_W-1:0] digest);

    always_ff @(negedge clk) begin
        if (digest_fifo_rd_val) begin
            put_digest(digest_fifo_rd_data);
        end
    end


/* *************************************************************************
* Simulation init
* *************************************************************************/
    import "DPI-C" context function void init_file_reader_state();
    initial begin
        init_file_reader_state();
    end

    export "DPI-C" function finish_from_c;
    function finish_from_c();
        $finish();
    endfunction
endmodule