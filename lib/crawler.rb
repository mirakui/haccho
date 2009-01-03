require 'rubygems'
require 'mechanize'
require 'logger'
require 'hpricot'
require 'kconv'
require 'gena/file_db'
require 'mysql'
require 'db'

module Haccho
  DL_COUNT_MAX     = $DEBUG ? 50 : 100_000
  PAGE_COUNT_MAX   = $DEBUG ? 1  :   3_000
  RETRY_MAX        = 3
  DMM_URI_BASE     = 'http://www.dmm.co.jp/rental/-/'
  BASE_DIR         = File.join File.dirname(__FILE__), '../'
  CACHE_DIR        = File.join BASE_DIR,   'cache'
  CONFIG_DIR       = File.join BASE_DIR,   'config'
  CONFIG_YAML_PATH = File.join CONFIG_DIR, 'config.yml'
  LAST_CID_PATH    = File.join CACHE_DIR,  'last_cid'

  class Crawler
    def initialize
      @agent          = WWW::Mechanize.new
      #WWW::Mechanize.html_parser = Hpricot
      @log            = Logger.new STDOUT
      @log.level      = Logger::DEBUG
      @config_file    = Gena::FileDB.new CONFIG_YAML_PATH
      @config         = @config_file.read_yaml || {}
      @blacklist      = @config['blacklist'] || []
      @last_cid_file  = Gena::FileDB.new LAST_CID_PATH
      @last_cid       = @last_cid_file.read
      @last_cid_wrote = false
      @rolled         = false
      @db             = DB.new
    end

    def logger=(logger)
      @log = logger
    end

    def start
      @log.info 'Crawler started'
      @crawled = []
      num = 1
      loop do
        if num > PAGE_COUNT_MAX
          @log.info "Stopped: reached page count max (#{PAGE_COUNT_MAX})"
          break
        end
        cids = crawl_list(num)
        crawl_cids(cids) or break
        num += 1
      end

      @log.info 'Crawler finished'
    end

private

    def crawl_list(num=1)
      @log.info "Crawl list page(#{num})"
      page = get num<=1 ? 'list/=/sort=date/' : "list/=/page=#{num}/"
      cids = page.links_with(:href => %r</cid=.+/$>).map {|link|
        link.href.match(%r</cid=(.+)/$>)[1]
      }
      cids.sort!.uniq!
      @log.info "Contents count: #{cids.length}"
      cids
    end

    def crawl_cids(cids)
      cids.each do |cid|
        @log.info "Next cid(#{@crawled.length}): [#{cid}]"
        if cid && @last_cid==cid
          @log.info "Stopped: reached last cid (#{@last_cid})"
          return nil
        elsif @crawled.length>=DL_COUNT_MAX
          @log.info "Stopped: reached download count max (#{DL_COUNT_MAX})"
          return nil
        end
        crawled = crawl_cid(cid)
        if crawled
          #@crawled << crawled
          @db.store(crawled)
          @last_cid_file.write(cid) unless @last_cid_wrote
          @last_cid_wrote = true
        end
      end
      return true
    end

    def crawl_cid(cid)
      result = nil
      begin
        result = {}
        page = get "detail/=/cid=#{cid}/"
        result['cid']           = cid
        result['uri']           = page.uri.to_s
        result['title']         = extract_title page
        result['keywords']      = extract_keywords page, cid
        result['thumb_images']  = extract_thumb_images page, cid
        result['description']   = extract_description page
        result['package_image'] = extract_package_image page, cid
        result['available_at']  = extract_available_at page
        result['playtime']      = extract_playtime page
        result['actress']       = extract_actress page
        result['series']        = extract_series page
        result['maker']         = extract_maker page
        result['label']         = extract_label page
        @log.info "Crawled: [#{cid}] #{result['title']}"
      rescue => e
        @log.warn "Skipped: [#{cid}] exception raised: "+ e.message
        result = nil
      end
      result
    end

    def extract_title(page)
      page.title.match(/^[^\[]+\[(.+)\][^\]]+$/)[1]
    end

    def extract_keywords(page, cid)
      keywords = ''
      (page / 'table.mg-b20 a').each do |a|
        if a['href']=~/keyword/
          keyword = a.text
          if @blacklist.include? keyword
            raise "Blacklisted(#{keyword})"
          else
            keywords += "[#{keyword}]"
          end
        end
      end
      keywords
    end

    def extract_thumb_images(page, cid)
      thumb_images = nil
      count = 0
      (page / 'img').each do |img|
        src = img['src']
        if src=~/-\d+\.jpg$/
          filename = sprintf("%s-%02d.jpg", cid, count)
          download_image src, filename
          thumb_images ||= []
          thumb_images << filename
          count += 1
        end
      end
      thumb_images
    end

    def extract_description(page)
      description = (page / 'div.clear.lh4').text
    end

    def extract_package_image(page, cid)
      uri = "http://pics.dmm.co.jp/mono/movie/#{cid}/#{cid}pl.jpg"
      package_image = download_image uri, "#{cid}.jpg"
    end

    def extract_available_at(page)
      (page / 'table.mg-b20 td')[1].text
    end

    def extract_playtime(page)
      (page / 'table.mg-b20 td')[3].text
    end

    def extract_actress(page)
      (page / 'table.mg-b20 td')[5].text
    end

    def extract_series(page)
      (page / 'table.mg-b20 td')[7].text
    end

    def extract_maker(page)
      (page / 'table.mg-b20 td')[9].text
    end

    def extract_label(page)
      (page / 'table.mg-b20 td')[11].text
    end

    def download_image(uri, name)
      file = @agent.get uri
      file_path =  File.join(image_dir(name), name)
      if File.exist?(file_path)
        @log.info "Already exists: #{uri}"
      else
        file.save_as file_path
        @log.info "Downloaded: #{uri}"
      end
      file.filename
    end

    def image_dir(name)
      dir_path = File.join CACHE_DIR, name[0,3]
      Dir.mkdir dir_path unless File.exist?(dir_path)
      dir_path
    end

    def get(query)
      uri = DMM_URI_BASE+query
      retry_count = 0
      begin
        result = @agent.get uri
        raise "Error result" if result.uri.to_s=~%r(/error/)
        return result
      rescue => e
        if retry_count < RETRY_MAX
          retry_count += 1
          @log.warn "Retry(#{retry_count}): #{uri}"
          retry
        else
          raise e
        end
      end
    end
  end
end
