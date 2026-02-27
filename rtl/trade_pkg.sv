package trade_pkg;

  parameter int PRICE_W = 16;   // e.g., cents or Q8.8
  parameter int SIZE_W  = 16;
  parameter int SEQ_W   = 24;

  typedef struct packed {
    logic [7:0]                 symbol;
    logic [PRICE_W-1:0]         price;
    logic [SIZE_W-1:0]          size;
    logic [SEQ_W-1:0]           seq;
  } tick_t;

  typedef struct packed {
    logic [7:0]                 symbol;
    logic                       side;   // 1=BUY, 0=SELL
    logic [SEQ_W-1:0]           seq;
    logic [15:0]                debug;  // optional
  } trig_t;

  localparam int TICK_W = $bits(tick_t);
  localparam int TRIG_W = $bits(trig_t);

endpackage