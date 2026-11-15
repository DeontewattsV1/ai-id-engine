bind fuzzy_extract fuzzy_extract_sva u_sva (
    .clk(clk), .rst_n(rst_n), .start(start), .puf(puf_raw[63:0]),
    .helper(helper_in[63:0]), .key_out(key_out), .ok(ok), .fail(fail),
    .done(done), .mode(mode));
