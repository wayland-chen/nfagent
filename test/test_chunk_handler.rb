
require 'test/test_helper'

class TestChunkHandler < ActiveSupport::TestCase
  setup do
    NFAgent::Config.config_file = "test/config"
    NFAgent::Config.init
    NFAgent::Config.plugin_directory = File.dirname(__FILE__) + '/../test/plugins/' 
    NFAgent::Plugin.load_plugins
    @logline = "1253604221  19 127.0.0.1 TCP_MISS/200 562 GET http://www.gravatar.com/blavatar/e81cfb9068d04d1cfd598533bb380e1f?s=16&d=http://s.wordpress.com/favicon.ico dan NONE/- text/html"
    @logline2 = "1253604221  19 127.0.0.1 TCP_MISS/200 562 GET http://www.gravatar.com/blavatar/e81cfb9068d04d1cfd598533bb380e1f?s=16&d=http://s.wordpress.com/favicon.ico paul NONE/- text/html"
  end

  test "append line" do
    chunk_handler = NFAgent::ChunkHandler.new
    chunk_handler.append(@logline)
    assert_equal 1, chunk_handler.chunk_group['all'].size
    assert_instance_of String, chunk_handler.chunk_group['all'][-1]
  end

  test "append with local parsing" do
    NFAgent::Config.parse = 'locally'
    chunk_handler = NFAgent::ChunkHandler.new
    chunk_handler.append(@logline)
    assert_equal 1, chunk_handler.chunk_group['all'].size
    assert_instance_of Squiggle::LogLine, chunk_handler.chunk_group['all'][-1]
  end

  test "append with multi" do
    NFAgent::Config.parse = 'locally'
    NFAgent::Config.mode = 'multi'
    NFAgent::Config.mapper = 'MyMapper'
    chunk_handler = NFAgent::ChunkHandler.new
    chunk_handler.append(@logline)
    assert chunk_handler.chunk_group.has_key?('acme')
    assert_equal 1, chunk_handler.chunk_group['acme'].size
    chunk_handler.append(@logline2)
    assert chunk_handler.chunk_group.has_key?('acme')
    assert chunk_handler.chunk_group.has_key?('jetson')
    assert_equal 1, chunk_handler.chunk_group['acme'].size
    assert_equal 1, chunk_handler.chunk_group['jetson'].size
  end

  test "reset chunk after expiry" do
    NFAgent::Config.parse = 'locally'
    NFAgent::Config.mode = 'multi'
    NFAgent::Config.mapper = 'MyMapper'
    NFAgent::Submitter.any_instance.expects(:perform).times(2)
    chunk_handler = NFAgent::ChunkHandler.new
    chunk_handler.append(@logline)
    Timecop.travel(30) do
      chunk_handler.append(@logline2)
      assert_equal 1, chunk_handler.chunk_group['acme'].size
      assert_equal 1, chunk_handler.chunk_group['jetson'].size

      Timecop.travel(31) do
        chunk_handler.check_full_or_expired
        assert !chunk_handler.chunk_group.has_key?('acme')
        assert_equal 1, chunk_handler.chunk_group['jetson'].size

        Timecop.travel(31) do
          chunk_handler.check_full_or_expired
          assert !chunk_handler.chunk_group.has_key?('acme')
          assert !chunk_handler.chunk_group.has_key?('jestson')
        end
      end
    end
  end

  test "reset chunk after full wuth check_full_or_expired" do
    NFAgent::Config.parse = 'locally'
    NFAgent::Config.mode = 'multi'
    NFAgent::Config.mapper = 'MyMapper'
    NFAgent::Submitter.any_instance.expects(:perform).times(2)
    chunk_handler = NFAgent::ChunkHandler.new(:chunk_size => 10)
    9.times { chunk_handler.append(@logline) }
    9.times { chunk_handler.append(@logline2) }
    assert_equal 9, chunk_handler.chunk_group['acme'].size
    assert_equal 9, chunk_handler.chunk_group['jetson'].size
    chunk_handler.append(@logline)
    chunk_handler.check_full_or_expired
    assert !chunk_handler.chunk_group.has_key?('acme')
    chunk_handler.append(@logline2)
    chunk_handler.check_full_or_expired
    assert !chunk_handler.chunk_group.has_key?('jetson')
  end

  test "fail an invalid logline in local parse mode" do
    NFAgent::Config.parse = 'locally'
    chunk_handler = NFAgent::ChunkHandler.new
    chunk_handler.append("") # Invalid logline
    assert chunk_handler.chunk_group['all'].nil?
  end
end
