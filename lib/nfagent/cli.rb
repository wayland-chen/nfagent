module NFAgent
  class CLI
    include NFAgent
    include SVUtil

    def initialize
      Config.init
      if Config.test_mode?
        Tests.run
        exit 1
      end
      @process = ProcessManager.new(Server, Config)
      @process.start
    end
  end
end

# TODO Run EventMachine here later to allow clients to connect for real time log display
