`define INSTRS 32

module tb;
  logic [`INSTRS-1:0][7:0] instrs;
  
  // cpu cpu ();
  initial begin
    $display("running %s tests\n",`TEST);
    $finish;
  end

  // assign ans = (x+y)*(x+y);
  // always begin
  //   #1;
  //   x++;
  //   if(y=={`SZ{1'b1}} && x=={`SZ{1'b1}})begin
  //     #1; $finish;
  //   end
  //   if(x=={`SZ{1'b1}})begin
  //     y++;
  //     // #1; $finish;
  //   end
  //   if(res !== ans) begin $display("res: %h ans: %h x: %h y: %h", res, ans, x-1, y); $finish; end

  // end

endmodule
 