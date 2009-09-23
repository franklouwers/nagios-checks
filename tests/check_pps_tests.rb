require "test/unit"
require "rubygems"
require "mocha"
require "snmp"
require "time"

class CheckPPS_Test <    Test::Unit::TestCase
  #helper function: catch output


  def catch_output
    original = $stdout
    catcher = StringIO.new

    $stdout = catcher
    begin
      yield
    ensure
      $stdout = original
    end
    catcher.string
  end

  #helper function to meddle with argv
  def run_script file, *args
    old_argv = ARGV
    Object.send(:remove_const, :ARGV)
    Object.const_set(:ARGV, args)
    load file
    Object.send(:remove_const, :ARGV)
    Object.const_set(:ARGV, old_argv)
  end

  def empty_cache
    mock_snmp = mock
    mock_snmp.expects(:walk).with(["ifOutUcastPkts","ifInUcastPkts","ifDescr","ifAlias","ifIndex","ifOutNUcastPkts","ifInNUcastPkts"]).yields(
    stub("goo", :value => 0), stub("foo", :value => 0), stub("foo", :value => "stub-1/0"), 
    stub("foo", :value => "alias"), stub("fii", :value => 42), stub("foo", :value => 0), 
    stub("foo", :value => 0))
    SNMP::Manager.expects(:open).yields(mock_snmp)
    Time.stubs(:now).returns(Time.parse("2009-01-01 08:30:30"))
    Kernel.expects(:exit).with(0)
    run_script 'check_pps.rb', "dontcare", "dontcare"
    
    
  end


  def test_should_give_ok_on_low_values
    #first clear previous values
    empty_cache
    #set time to 1 sec later
    Time.stubs(:now).returns(Time.parse("2009-01-01 08:30:31"))

    mock_snmp = mock
    mock_snmp.expects(:walk).with(["ifOutUcastPkts","ifInUcastPkts","ifDescr","ifAlias","ifIndex","ifOutNUcastPkts","ifInNUcastPkts"]).yields(
    stub("goo", :value => 1), stub("foo", :value => 1), stub("foo", :value => "stub-1/0"), 
    stub("foo", :value => "alias"), stub("fii", :value => 42), stub("foo", :value => 1), 
    stub("foo", :value => 1))
    
    Kernel.expects(:exit).with(0)

    SNMP::Manager.expects(:open).yields(mock_snmp)
    response = catch_output do
      run_script 'check_pps.rb', "dontcare", "dontcare", 100, 200
    end

    assert_equal "OK\n", response
  end

  def test_should_give_warning_on_medium_values
    #first clear previous values
    empty_cache
    #set time to 1 sec later
    Time.stubs(:now).returns(Time.parse("2009-01-01 08:30:31"))
    mock_snmp = mock
    mock_snmp.expects(:walk).with(["ifOutUcastPkts","ifInUcastPkts","ifDescr","ifAlias","ifIndex","ifOutNUcastPkts","ifInNUcastPkts"]).yields(
    stub("goo", :value => 1), stub("foo", :value => 1), stub("foo", :value => "stub-1/0"), 
    stub("foo", :value => "alias"), stub("fii", :value => 42), stub("foo", :value => 101), 
    stub("foo", :value => 1))

    Kernel.expects(:exit).with(1) #exit 1 = warn


    SNMP::Manager.expects(:open).yields(mock_snmp)
    response = catch_output do
      run_script 'check_pps.rb', "dontcare", "dontcare", "100", "200"
    end

    assert_match /^WARNING .*$/, response
  end
  
  def test_should_give_critical_on_high_values
    #first clear previous values
    empty_cache
    #set time to 1 sec later
    Time.stubs(:now).returns(Time.parse("2009-01-01 08:30:31"))
    mock_snmp = mock
    mock_snmp.expects(:walk).with(["ifOutUcastPkts","ifInUcastPkts","ifDescr","ifAlias","ifIndex","ifOutNUcastPkts","ifInNUcastPkts"]).yields(
    stub("goo", :value => 1), stub("foo", :value => 1), stub("foo", :value => "stub-1/0"), 
    stub("foo", :value => "alias"), stub("fii", :value => 42), stub("foo", :value => 201), 
    stub("foo", :value => 1))

    Kernel.expects(:exit).with(2) #exit 2 = crit


    SNMP::Manager.expects(:open).yields(mock_snmp)
    response = catch_output do
      run_script 'check_pps.rb', "dontcare", "dontcare", "100", "200"
    end

    assert_match /^CRITICAL .*$/, response
  end
  
# als foute snmp community: SNMP::RequestTimeout

end