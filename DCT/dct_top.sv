/*
top
├── pixel_buffer       // stream in pixels, output 8x8 blocks
├── dct_2d             // 2D 8x8 DCT
│   ├── dct_1d         // 1D 8-point DCT (row pass)
│   ├── transpose_buf  // stores row-DCT results, feeds column pass
│   └── dct_1d         // 1D 8-point DCT (col pass)
├── quantizer          // divide by Q-table, round
├── zigzag_scan        // reorder 8x8 block to 1D zigzag
├── rle_encoder        // run-length encode (AC coefficients)
└── huffman_encoder    // entropy code DC/AC symbols → bitstream
*/




