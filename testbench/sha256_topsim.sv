`include "sha256_defs.svh"
module sha256_topsim();
    localparam  CLOCK_PERIOD      = 10000;
    localparam  CLOCK_HALF_PERIOD = CLOCK_PERIOD/2;
    localparam  RST_TIME          = 10 * CLOCK_PERIOD;

    logic   clk;
    logic   rst;
    
    logic                           file_manager_data_val;
    logic   [SHA_IF_DATA_W-1:0]     file_manager_data;
    logic                           file_manager_data_last;
    logic                           manager_file_rdy;
    
    logic                           manager_file_digest_val;
    logic   [SHA256_DIGEST_W-1:0]   manager_file_digest;
    logic                           file_manager_digest_rdy;
    
    logic                           manager_core_init;
    logic                           manager_core_next;
    logic                           manager_core_mode;
    logic   [SHA256_BLOCK_W-1:0]    manager_core_block;
    logic                           core_manager_ready;

    logic   [SHA256_DIGEST_W-1:0]   core_manager_digest;
    logic                           core_manager_digest_valid;

    
    initial begin
        clk = 0;
        forever begin
            #(CLOCK_HALF_PERIOD) clk = ~clk;
        end
    end

    initial begin
        rst = 1'b1;
        #RST_TIME rst = 1'b0;
    end

    sha256_sim_file_reader sim_file_reader (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.file_dst_data_val     (file_manager_data_val  )
        ,.file_dst_data         (file_manager_data      )
        ,.file_dst_data_last    (file_manager_data_last )
        ,.dst_file_rdy          (manager_file_rdy       )

        ,.src_file_digest_val   (manager_file_digest_val)
        ,.src_file_digest       (manager_file_digest    )
        ,.file_src_digest_rdy   (file_manager_digest_rdy)
    );

    sha256_manager manager (
         .clk   ()
        ,.rst   ()

        ,.src_manager_data_val      (file_manager_data_val      )
        ,.src_manager_data          (file_manager_data          )
        ,.src_manager_data_last     (file_manager_data_last     )
        ,.manager_src_rdy           (manager_file_rdy           )

        ,.manager_dst_digest_val    (manager_file_digest_val    )
        ,.manager_dst_digest        (manager_file_digest        )
        ,.dst_manager_digest_rdy    (file_manager_digest_rdy    )

        ,.manager_core_init         (manager_core_init          )
        ,.manager_core_next         (manager_core_next          )
        ,.manager_core_mode         (manager_core_mode          )
        ,.manager_core_block        (manager_core_block         )
        ,.core_manager_ready        (core_manager_ready         )
                                     
        ,.core_manager_digest       (core_manager_digest        )
        ,.core_manager_digest_valid (core_manager_digest_valid  )
    );

    sha256_core DUT (
         .clk       (clk    )
        ,.reset_n   (~rst   )

        ,.init          (manager_core_init          )
        ,.next          (manager_core_next          )
        ,.mode          (manager_core_mode          )
        ,.block         (manager_core_block         )
        ,.ready         (core_manager_ready         )

        ,.digest        (core_manager_digest        )
        ,.digest_valid  (core_manager_digest_valid  )
    );
endmodule