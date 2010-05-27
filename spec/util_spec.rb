require File.expand_path('../spec_helper', __FILE__)

require 'isono'
include Isono

require 'stringio'
require 'eventmachine'

describe Isono::Util do

  it "gen_id" do
    Util.gen_id.length.should > 0
  end

  it "quote_args" do
    Util.quote_args('/bin/ls').should == '/bin/ls'
    Util.quote_args('/bin/ls %s', %w[/home]).should == '/bin/ls \'/home\''
    Util.quote_args('/bin/ls %s', ['$a']).should == '/bin/ls \'\\$a\''
  end

  it "system" do
    io = StringIO.new

    EM.run {
      EM.defer {
        begin
          Util.system('/bin/ls', [], {:io=>io})
          puts io.string
        io.string.length.should > 0
        EM.next_tick {EM.stop}
      rescue => e
          p e
        end
      }
    }
  end

end
