require 'rubygems'
require 'mechanize'
require 'logger'
require 'hpricot'
require 'kconv'
require 'gena/file_db'

module Haccho
  DL_COUNT_MAX     = $DEBUG ? 50 : 100_000
  PAGE_COUNT_MAX   = $DEBUG ? 1  :   3_000
  DMM_URI_BASE     = 'http://www.dmm.co.jp/rental/-/'
  BASE_DIR         = File.join File.dirname(__FILE__), '../'
  CACHE_DIR        = File.join BASE_DIR,   'cache'
  CONFIG_DIR       = File.join BASE_DIR,   'config'
  DL_YAML_PATH     = File.join CACHE_DIR,  'downloaded.yml'
  CONFIG_YAML_PATH = File.join CONFIG_DIR, 'config.yml'
  LAST_CID_PATH    = File.join CACHE_DIR,  'last_cid'

  class Crawler
    def initialize
      @agent          = WWW::Mechanize.new
      #WWW::Mechanize.html_parser = Hpricot
      @log            = Logger.new STDOUT
      @log.level      = Logger::DEBUG
      @dl_file        = Gena::FileDB.new DL_YAML_PATH
      @config_file    = Gena::FileDB.new CONFIG_YAML_PATH
      @config         = @config_file.read_yaml || {}
      @blacklist      = @config['blacklist'] || []
      @last_cid_file  = Gena::FileDB.new LAST_CID_PATH
      @last_cid       = @last_cid_file.read
      @last_cid_wrote = false
      @rolled         = false
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
        unless @rolled
          @dl_file.roll :daily
          @rolled = true
        end
        @dl_file.write @crawled.to_yaml
        @log.info "Wrote: #{@dl_file.path}"
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
          @crawled << crawled
          @last_cid_file.write(cid) unless @last_cid_wrote
          @last_cid_wrote = true
        end
      end
      return true
    end

    def crawl_cid(cid)
      result = {}
      page = get "detail/=/cid=#{cid}/"
      result['cid'] = cid
      result['uri'] = page.uri.to_s
      result['title'] = page.title.match(/^[^\[]+\[(.+)\][^\]]+$/)[1]
      result['keywords'] = []
      (page / 'table.mg-b20 a').each do |a|
        if a['href']=~/keyword/
          keyword = a.text
          if @blacklist.include? keyword
            @log.info "Blacklisted(#{keyword}): [#{cid}] #{result['title']}"
            return nil
          else
            result['keywords'] << keyword
          end
        end
      end
      (page / 'img').each do |img|
        src = img['src']
        cid_short = cid.split(/[a-z]+$/i).join
        if src=~/#{cid_short}/ && !(src=~/ps.jpg/)
          filename = download_image src
          result['thumb_images'] ||= []
          result['thumb_images'] << filename
        end
      end
      result['description'] = (page / 'div.clear.lh4').text
      uri = "http://pics.dmm.co.jp/mono/movie/#{cid}/#{cid}pl.jpg"
      result['package_image'] = download_image uri
      @log.info "Crawled: [#{cid}] #{result['title']}"
      result
    end

    def download_image(uri)
      file = @agent.get uri
      file.save_as File.join(CACHE_DIR, file.filename)
      @log.info "Downloaded: #{uri}"
      file.filename
    end

    def get(query)
      @agent.get DMM_URI_BASE+query
    end
  end
end
