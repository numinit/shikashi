require "rubygems"
require "shikashi"

include Shikashi

$top_level_binding = binding

describe Sandbox, "Shikashi sandbox" do
  it "should run empty code without privileges" do
    Sandbox.new.run ""
  end

  it "should run empty code with privileges" do
    Sandbox.new.run "", Privileges.new
  end

  class X
    def foo
    end
  end
  it "should raise SecurityError when call method without privileges" do

    x = X.new

    lambda {
      Sandbox.new.run "x.foo", binding, :no_base_namespace => true
    }.should raise_error(SecurityError)

  end

  it "should not raise anything when call method with privileges" do

    x = X.new
    privileges = Privileges.new
    def privileges.allow?(*args)
      true
    end

    Sandbox.new.run "x.foo", binding, :privileges => privileges, :no_base_namespace => true

  end


  module ::A4
    module B4
      module C4

      end
    end
  end

  it "should allow use a class declared inside" do
    priv = Privileges.new
    priv.allow_method :new
    Sandbox.new.run("
      class ::TestInsideClass
        def foo
        end
      end

      ::TestInsideClass.new.foo
    ", priv)
  end

  it "should use base namespace when the code uses colon3 node (2 levels)" do
    Sandbox.new.run( "::B4",
        :base_namespace => A4
    ).should be == A4::B4
  end

  it "should change base namespace when classes are declared (2 levels)" do
    Sandbox.new.run( "
                class ::X4
                   def foo
                   end
                end
            ",
        :base_namespace => A4
    )

    A4::X4
  end

  it "should use base namespace when the code uses colon3 node (3 levels)" do
    Sandbox.new.run( "::C4",
        $top_level_binding, :base_namespace => ::A4::B4
    ).should be == ::A4::B4::C4
  end

  it "should change base namespace when classes are declared (3 levels)" do
    Sandbox.new.run( "
                class ::X4
                   def foo
                   end
                end
            ",
        $top_level_binding, :base_namespace => ::A4::B4
    )

    A4::B4::X4
  end

  it "should reach local variables when current binding is used" do
    a = 5
    Sandbox.new.run("a", binding, :no_base_namespace => true).should be == 5
  end

  class N
    def foo
      @a = 5
      Sandbox.new.run("@a", binding, :no_base_namespace => true)
    end
  end


  it "should allow reference to instance variables" do
     N.new.foo.should be == 5
  end

  it "should create a default module for each sandbox" do
     s = Sandbox.new
     s.run('class X
              def foo
                 "foo inside sandbox"
              end
            end')

     x = s.base_namespace::X.new
     x.foo.should be == "foo inside sandbox"
  end

  it "should not allow xstr when no authorized" do
    s = Sandbox.new
    priv = Privileges.new

    lambda {
      s.run("%x[echo hello world]", priv)
    }.should raise_error(SecurityError)

  end

  it "should allow xstr when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_xstr

    lambda {
      s.run("%x[echo hello world]", priv)
    }.should_not raise_error

  end

  class Context
    def get_binding
      binding
    end
  end

  class ContextOne < Context
  end

  class ContextTwo < Context
    def ` str
      str.reverse
    end
  end

  it "should execute xstr in the correct binding" do
    s = Sandbox.new
    priv = Privileges.new
    priv.allow_xstr
    ctx1, ctx2 = ContextOne.new, ContextTwo.new
    cmd  = "echo hello world"
    xstr = "%x[#{cmd}]"
    s.run(xstr, priv, binding: ctx1.get_binding).should be == ctx1.get_binding.eval(xstr)
    s.run(xstr, priv, binding: ctx2.get_binding).should be == ctx2.get_binding.eval(xstr)
  end

  it "should not allow global variable read" do
    s = Sandbox.new
    priv = Privileges.new

    lambda {
      s.run("$a", priv)
    }.should raise_error(SecurityError)
  end

  it "should allow global variable read when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_global_read(:$a)

    lambda {
      s.run("$a", priv)
    }.should_not raise_error
  end

  it "should not allow constant variable read" do
    s = Sandbox.new
    priv = Privileges.new

    TESTCONSTANT9999 = 9999
    lambda {
      s.run("TESTCONSTANT9999", priv)
    }.should raise_error(SecurityError)
  end

  it "should allow constant read when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_const_read("TESTCONSTANT9998")
    ::TESTCONSTANT9998 = 9998

    lambda {
      s.run("TESTCONSTANT9998", priv).should be == 9998
    }.should_not raise_error
  end

  it "should allow read constant nested on classes when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_const_read("Fixnum")
    Fixnum::TESTCONSTANT9997 = 9997

    lambda {
      s.run("Fixnum::TESTCONSTANT9997", priv).should be == 9997
    }.should_not raise_error
  end


  it "should not allow global variable write" do
    s = Sandbox.new
    priv = Privileges.new

    lambda {
      s.run("$a = 9", priv)
    }.should raise_error(SecurityError)
  end

  it "should allow global variable write when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_global_write(:$a)

    lambda {
      s.run("$a = 9", priv)
    }.should_not raise_error
  end

  it "should not allow constant write" do
    s = Sandbox.new
    priv = Privileges.new

    lambda {
      s.run("TESTCONSTANT9999 = 99991", priv)
    }.should raise_error(SecurityError)
  end

  it "should allow constant write when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_const_write("TESTCONSTANT9998")

    lambda {
      s.run("TESTCONSTANT9998 = 99981", priv)
      TESTCONSTANT9998.should be == 99981
    }.should_not raise_error
  end

  it "should allow write constant nested on classes when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_const_read("Fixnum")
    priv.allow_const_write("Fixnum::TESTCONSTANT9997")

    lambda {
      s.run("Fixnum::TESTCONSTANT9997 = 99971", priv)
      Fixnum::TESTCONSTANT9997.should be == 99971
    }.should_not raise_error
  end

  it "should allow package of code" do
    s = Sandbox.new

    lambda {
      s.packet('print "hello world\n"')
    }.should_not raise_error
  end

  def self.package_oracle(args1, args2)
     it "should allow and execute package of code" do
       e1 = nil
       e2 = nil
       r1 = nil
       r2 = nil

       begin
         s = Sandbox.new
         r1 = s.run(*(args1+args2))
       rescue Exception => e
         e1 = e
       end

       begin
         s = Sandbox.new
         packet = s.packet(*args1)
         r2 = packet.run(*args2)
       rescue Exception => e
         e2 = e
       end

       e1.should be == e2
       r1.should be == r2
     end
  end

  class ::XPackage
    def foo

    end
  end

  package_oracle ["1"], [:binding => binding]
  package_oracle ["1+1",{ :privileges => Privileges.allow_method(:+)}], [:binding => binding]

  it "should accept references to classes defined on previous run" do
    sandbox = Sandbox.new

    sandbox.run("class XinsideSandbox
    end")

    sandbox.run("XinsideSandbox").should be == sandbox.base_namespace::XinsideSandbox
  end

  class OutsideX44
    def method_missing(name)
      name
    end
  end
  OutsideX44_ins = OutsideX44.new

  it "should allow method_missing handling" do
    sandbox = Sandbox.new
    privileges = Privileges.new
    privileges.allow_const_read("OutsideX44_ins")
    privileges.instances_of(OutsideX44).allow :method_missing

    sandbox.run("OutsideX44_ins.foo", privileges).should be == :foo
  end
end
