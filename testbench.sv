//transaction object which will keep track of a variable for each input and output port which are present in dut.
class transaction;
  rand bit [7:0] loadin;   //using pseudo random number generator for generating a random value.
  //for rst,up,load we will be manually generating stimuli
  bit rst;
  bit up;
  bit load;
  bit [7:0] y;
endclass

//generator allows us to generate the random transactions for all the ports for which we have added the rand keyword in transaction class and send it to driver with the help of mailbox

class generator;
  //We need to add an instance of a transaction where we will be adding the random data, which finally goes to a driver.
  //mailbox, which is a communication mechanism to send the data to a driver.
  //as soon as driver applies a stimuli to dut, we need to generate the new stimuli.So Driver conveys information of completion of its processes with the help of an event.
  transaction t;
  mailbox mbx;
  event done;
  
  //We have added the standard constructor for the generator where we will be expecting the mailbox argument from an user.
  function new(mailbox mbx);
    this.mbx=mbx;
  endfunction
  
  //main task
  task run();
    t=new();
    for(int i=0;i<200;i++) begin
      if(!t.randomize()) //This will genarate random value for loadin
        $display("[GEN]:randomization failed");
      else begin
        mbx.put(t);  //To send the data to driver
        $display("[GEN]:Data send to driver");
      end
      @(done);
    end
  endtask
  
endclass

//driver which need to apply the stimuli that it received from a generator to the dut.

class driver;
  transaction t; //The data received will be stored in the transaction. 
  mailbox mbx; //mailbox with the help of which we will be receiving a data from a generator.
  event done;  //done which is used to convey the completion of the process of application of the stimuli to a dut.
  
  virtual counter_8_inf vif; //interface which allow us to apply the random transactions to a dut.
  
  function new(mailbox mbx);
    this.mbx=mbx;
  endfunction
  
  task run();
    t=new();
    forever begin
      mbx.get(t);   //To receive the data from genertor
      vif.loadin <= t.loadin;
      $display("[DRV]: Trigger Interface");
      @(posedge vif.clk);
      ->done;      //We wait for the positive edge of a clock and then we trigger the done signal.So after we trigger done signal, generator will send us the new stimuli.
    end
  endtask
  
endclass

//monitor,used to recieve the response from dut and send it to scoreboard for comparision.
      
class monitor;
  virtual counter_8_inf vif;  //interface used to access the response of the duty. 
  mailbox mbx;      //mailbox used to send the data to a scoreboard for comparison.
  transaction t;
  
  //Adding Functional Coverage
  covergroup c;
    option.per_instance=1; //allowa us to see the detail analysis
    
    //reponse of dut is in the datamembers of transaction class
    coverpoint t.rst{
      bins rst_l={0};
      bins rsth={1};
    }
    
    coverpoint t.load{
      bins load_l={0};
      bins load_h={1};
    }
    
    coverpoint t.loadin{
      bins lower={[0:84]};
      bins mid={[85:169]};
      bins high={[170:255]};
    }
    
    coverpoint t.y{
      bins y_lower={[0:84]};
      bins y_mid={[85:169]};
      bins y_high={[170:255]};
    }
    
    coverpoint t.up{
      bins up_l={0};
      bins up_h={1};
    }
    
    cross_load_loadin:cross t.load,t.loadin{
      ignore_bins unused_load=binsof(t.load)intersect{0};
    }
    
    cross_rst_up:cross t.rst,t.up{
      ignore_bins unused_rst=binsof(t.rst)intersect{1};
    }
    
    cross_rst_y:cross t.rst,t.y{
      ignore_bins unused_rst=binsof(t.rst)intersect{1};
    }
    
  endgroup
  
  function new(mailbox mbx);
    this.mbx=mbx;
    c=new();
  endfunction
  
  task run();
    t=new();
    forever begin
      t.loadin = vif.loadin;
      t.rst = vif.rst;
      t.up = vif.up;
      t.load = vif.load;
      t.y = vif.y;
      c.sample();
      mbx.put(t);  ///used to send the data to scoreboard
      $display("[MON]:Data send to scoreboard");
      @(posedge vif.clk);  
    end
  endtask
  
endclass

class scoreboard;
  transaction t;
  mailbox mbx;
  
  function new(mailbox mbx);
    this.mbx=mbx;
  endfunction
  
  task run();
    t=new();
    forever begin
      mbx.get(t);
    end
  endtask
  
endclass

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  virtual counter_8_inf vif;
  
  mailbox gdmbx;  //mailbox working between generator and driver
  mailbox msmbx;  //mailbox working betwee monitor and scoreboard
  
  event gddone;
  
  function new(mailbox gdmbx,mailbox msmbx);
    this.gdmbx = gdmbx;
    this.msmbx = msmbx;
    
    gen = new(gdmbx);
    drv = new(gdmbx);
    
    mon = new(msmbx);
    sco = new(msmbx);
  endfunction
  
  task run();
    gen.done = gddone;
    drv.done = gddone;
    
    drv.vif = vif;
    mon.vif = vif;
    
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
    
  endtask
  
endclass


module tb();
  environment env;
  
  mailbox gdmbx;
  mailbox msmbx;
  
  counter_8_inf vif();
  
  counter_8 dut(vif.clk,vif.rst,vif.up,vif.load,vif.loadin,vif.y);
  
  always #5 vif.clk = ~vif.clk;
  
  initial begin
    vif.clk=0;
    vif.rst=1;
    #50;
    vif.rst=0;
  end
  
  initial begin
    #60;
    repeat(20) begin
      vif.load=1;
      #10;
      vif.load=0;
      #100;
    end
  end
  
  initial begin
    #60;
    repeat(20) begin
      vif.up=1;
      #70;
      vif.up=0;
      #70;
    end
  end
  
  initial begin
    gdmbx = new();
    msmbx = new();
    env = new(gdmbx,msmbx);
    env.vif=vif;
    env.run();
    #2000;
    $finish();
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
  
endmodule
    
  
    