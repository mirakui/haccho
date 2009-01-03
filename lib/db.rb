require 'rubygems'
require 'pp'
require 'pit'
require 'mysql'
require 'logger'

module Haccho
  class DB
    def initialize
      conf = Pit.get('haccho_mysql', :require=>{
        'username' => 'username',
        'password' => 'password',
        'database' => 'database',
        'host'=> 'host'
      })
      @db = Mysql.new conf['host'], conf['username'], conf['password'], conf['database']
    end

    def store(entry)
      query = <<-QUERY
INSERT IGNORE INTO
  entries
  (cid, title, description, keywords, available_at,
   playtime, actress, series, maker, label)
VALUES
  (?,?,?,?,?,
   ?,?,?,?,?)
      QUERY
      st = @db.prepare(query)
      st.execute(
        entry['cid'], entry['title'], entry['description'],
        entry['keywords'], entry['available_at'],
        entry['playtime'], entry['actress'], entry['series'],
        entry['maker'], entry['label']
      )
      st.close
    end

    def close
      @db.close
    end
  end
end
