package sha256_pkg;
`include "bsg_defines.v"
    localparam  SHA_IF_DATA_W = 256;
    localparam  SHA_IF_BITS_W = `BSG_SAFE_CLOG2(256);
    localparam  SHA_IF_BYTES = 256/8;
    localparam  SHA_IF_BYTES_W = `BSG_SAFE_CLOG2(SHA_IF_BYTES);
    localparam  SHA256_DIGEST_W = 256;
    localparam  SHA256_BLOCK_W = 512;
    localparam  SHA256_BLOCK_BYTES = 512/8;
    localparam  SHA256_BLOCK_BYTES_W = `BSG_SAFE_CLOG2(SHA256_BLOCK_BYTES);

endpackage