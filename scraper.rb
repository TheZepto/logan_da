# Adapted from planningalerts.org.au to return data
# back to Jan 01, 2007

require 'scraperwiki'
require 'mechanize'
require 'date'

def scrape_page(page)
  page.at("table.rgMasterTable").search("tr.rgRow,tr.rgAltRow").each do |tr|
    begin
      tds = tr.search('td').map{|t| t.inner_html.gsub("\r\n", "").strip}
      day, month, year = tds[2].split("/").map{|s| s.to_i}
      record = {
        "info_url" => (page.uri + tr.search('td').at('a')["href"]).to_s,
        "council_reference" => tds[1],
        "date_received" => Date.new(year, month, day).to_s,
        "description" => tds[3].gsub("&amp;", "&").split("<br>")[1].to_s.squeeze(" ").strip,
        "address" => tds[3].gsub("&amp;", "&").split("<br>")[0].gsub("\r", " ").gsub("<strong>","").gsub("</strong>","").squeeze(" ").strip,
        "date_scraped" => Date.today.to_s
      }
      if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
#         puts "Saving record " + record['council_reference'] + " - " + record['address']
#        puts record
        ScraperWiki.save_sqlite(['council_reference'], record)
#       else
#         puts "Skipping already saved record " + record['council_reference']
      end
    rescue
      puts "Page is empty."
      next
    end
  end
end


# Implement a click on a link that understands stupid asp.net doPostBack
def click(page, doc)
  begin
    js = doc["href"] || doc["onclick"]
    if js =~ /javascript:__doPostBack\('(.*)','(.*)'\)/
      event_target = $1
      event_argument = $2
      form = page.form_with(id: "aspnetForm")
      form["__EVENTTARGET"] = event_target
      form["__EVENTARGUMENT"] = event_argument
      form.submit
    elsif js =~ /return false;__doPostBack\('(.*)','(.*)'\)/
      nil
    else
      # TODO Just follow the link likes it's a normal link
      raise
    end
  rescue
    nil
  end
end

years = [2017, 2016, 2015, 2014, 2013, 2012, 2011, 2010, 2009, 2008, 2007]
periodstrs = years.map(&:to_s).product([*'-01'..'-12'].reverse).map(&:join).select{|d| d <= Date.today.to_s[0..-3]}.reverse

url_ends = ['&4=916&4a=916', '&4=901&4a=901', '&4=556&4a=556', '&4=921&4a=921', '&4=559&4a=559']

url_ends.each {|url_end|
  periodstrs.each {|periodstr|
    
    matches = periodstr.scan(/^([0-9]{4})-(0[1-9]|1[0-2])$/)
    period = "&1=" + Date.new(matches[0][0].to_i, matches[0][1].to_i, 1).strftime("%d/%m/%Y")
    period = period + "&2=" + Date.new(matches[0][0].to_i, matches[0][1].to_i, -1).strftime("%d/%m/%Y")

    puts "Getting data in `" + periodstr + "`."


    url = "http://pdonline.logan.qld.gov.au/MasterViewUI/Modules/ApplicationMaster/default.aspx?page=found" + period + url_end
    
    agent = Mechanize.new

    # Read in a page
    page = agent.get(url)


    # This is weird. There are two forms with the Agree / Disagree buttons. One of them
    # works the other one doesn't. Go figure.
    form = page.forms[1]
    button = form.button_with(value: "Agree")
    raise "Can't find agree button" if button.nil?
    page = form.submit(button)

    current_page_no = 1
    next_page_link = true

    while next_page_link
      if (current_page_no%5) == 0
        puts "Scraping page #{current_page_no}..."
      end
      scrape_page(page)

      current_page_no += 1
      next_page_link = page.at(".rgPageNext")
      page = click(page, next_page_link)
      next_page_link = nil if page.nil?
    end
    }
  }
