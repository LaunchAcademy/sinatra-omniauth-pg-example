class Database
  def self.connection
    begin
      config = Sinatra::Application.settings.database_config
      connection = PG.connect(config)
      yield(connection)
    ensure
      connection.close
    end
  end
end
