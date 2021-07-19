// C++ includes
//#include <cstring>
#include <fstream>
#include <iostream>
#include <cstdint>

// C includes
#include "svdpi.h"

#define SHA_IF_DATA_W 256
#define SHA256_DIGEST_W 256

struct input_file_state {
    std::ifstream input_file;
};


struct input_file_state input_state;

/*******************************************************************
 * Function declarations
 ******************************************************************/
// Verilog function imports
extern "C" void drive_input_if(bool val, svBitVecVal *data, bool last);
extern "C" void finish_from_c(void);

// Functions exported to Verilog
extern "C" void get_input_data(void);
extern "C" void put_digest(svBitVecVal *digest);
extern "C" void init_file_reader_state(void);

/********************************************************************
 * Input data
 *******************************************************************/
extern "C" void get_input_data() {
    svBitVecVal input_data[SHA_IF_DATA_W >> 5];
    uint8_t buffer_data[SHA_IF_DATA_W/8];
    uint8_t *input_data_copy_ptr = (uint8_t *)input_data;

    if (~input_state.input_file.eof()) {
        input_state.input_file.read((char *)buffer_data, SHA_IF_DATA_W >> 3);

        // copy data into the svBitVecVal
        for (int i = (SHA_IF_DATA_W >> 3) - 1; i >= 0; i--) {
            input_data_copy_ptr[i] = buffer_data[((SHA_IF_DATA_W/8)-1) - i];
        }

        if (input_state.input_file.eof()) {
            drive_raw_if(true, input_data, true);
        }
        else {
            drive_raw_if(true, input_data, false);
        }
    }
    else {
        memset(input_data_copy_ptr, 0, SHA_IF_DATA_W >> 3);
        drive_input_if(false, input_data, false);
    }
}
/********************************************************************
 * Digest output
 *******************************************************************/
extern "C" void put_digest(svBitVecVal *digest) {
    uint8_t dpi_vector = (uint8_t *)digest;
    uint8_t write_buf[SHA_IF_DATA_W/8];

    // flip the outputted data?
    for (int i = (SHA_IF_DATA_W >> 3) - 1; i  >= 0; i--) {
        write_buf[(SHA_IF_DATA_W/8) - 1 - i] = dpi_vector[i];
    }

    finish_from_c();
}

/********************************************************************
 * Initialization code
 *******************************************************************/

extern "C" void init_file_reader_state() {
    svBitVecVal init_data[SHA_IF_DATA_W >> 5];
    uint8_t *init_data_copy_ptr = (uint8_t *)init_data;

    input_state.input_file.open("test_file.txt.padded", ios::binary);

    memset(init_data_copy_ptr, 0, SHA_IF_DATA_W >> 3);
    drive_raw_if(false, init_data);
}
