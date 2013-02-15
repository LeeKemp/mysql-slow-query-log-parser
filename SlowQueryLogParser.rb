#!/usr/bin/ruby -w

#
# --------------------------------------------------------------------------------
#                      MYSQL SLOW QUERY LOG PARSER
# --------------------------------------------------------------------------------
#
# http://code.google.com/p/mysql-slow-query-log-parser
#
# Inspired by on the perl MySQL slow query log parser written by 
# Nathanial Hendler (http://retards.org/)  
#
# Any suggestions or fixes are more then welcome. 
# lee (at) kumkee (dot) com
#
# --------------------------------------------------------------------------------
# USAGE
# --------------------------------------------------------------------------------
#
# ruby SlowQueryLogParser [Path to log] [Order By]
# 
# eg.
# ruby SlowQueryLogParser query.log lock
#
# Order By Options:
# - lock 
# - time
# - number
# 
# --------------------------------------------------------------------------------
# TODO
# --------------------------------------------------------------------------------
#
# - Parse server info at the top of the log
# - Add date / time selection
# - XML Output
# - Totals information / stats
#
# --------------------------------------------------------------------------------
# UPADATE LOG
# --------------------------------------------------------------------------------
#
# 2007-06-06 - Version 0.1 Alpha
#     First version with basic parsing of log file & basic sorting
# 2009-02-20
#     Support for multiline queries by Jacob Kjeldahl
# 2011-06-27
#     Fix for bug where minimum time and lock always compute to 0 by Benoit Soenen
#
# --------------------------------------------------------------------------------
#
# MySQL Slow Query Log Parser.
#
# Copyright 2007-2011 Lee Kemp
#
# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at 
# 
# http://www.apache.org/licenses/LICENSE-2.0 
# 
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and 
# limitations under the License. 
#

require 'date'

# Vars
logPath = ARGV[0]
orderBy = ARGV[1]

version = "0.1 Alpha"
spacer = "#" * 80

# Print page header
puts spacer
puts
puts "MySQL Slow Query Log Parser v #{version}"
puts
puts Time::now()
puts "Output for #{logPath} ordered by #{orderBy}"
puts
puts spacer
puts
# This array holds all the query objects after they have been read from the text file
queries = Array.new

# This hash holds the QueryTotals using the normalized SQL query as the key
queryTotals = Hash.new

class Query

  def initialize(sql, date, time, lock, rows, sent, user, url, ip)
    @sql     = sql
    @date    = date
    @time    = time.to_i
    @lock   = lock.to_i
    @rows = rows.to_i
    @sent   = sent.to_i
    @user = user
    @url = url
    @ip = ip

    # Normalize sql query using RegExp from perl parser
    @normalized_query =  @sql.gsub(/\d+/, "XXX") # Replace numbers
    @normalized_query =  @normalized_query.gsub(/([\'\"]).+?([\'\"])/, "XXX") # Replace strings
    #@normalized_query =  @normalized_query.gsub(/\/\*[A-Za-z0-9\W\S]*/, "") # Remove comments '/* blah */
  end
  
  def getNormalizedQuery()  
    @normalized_query
  end
  
  def getUser()
    @user
  end
  
  def getUrl()
    @url
  end
  
  def getIp()
    @ip
  end
  
  def getTime()
    @time
  end

  def getLock()
    @lock
  end
  
  def to_s
      "Date: #{@date}, Time #{@time}, Lock #{@lock}, Sent #{@sent}, Rows #{@rows} \n #{@sql}"
  end
end

class QueryTotal

  def initialize(sql)
    @sql     = sql
    @queries = Array.new
    @max_time = 0
    @max_lock = 0
    @min_time = -1
    @min_lock = -1
    
  end

  def addQuery(query)
    @queries.push(query)
    
    if @max_time < query.getTime then
      @max_time = query.getTime
    end
    
    if @max_lock < query.getLock then
      @max_lock = query.getLock
    end

    if @min_time > query.getTime or @min_time == -1 then
       @min_time = query.getTime
    end

    if @min_lock > query.getLock or @min_lock == -1 then
       @min_lock = query.getLock
    end
     
  end

  def getUser()
    for query in @queries
        user = query.getUser
    end
    user
  end
    
  def getUrl()
    for query in @queries
        url = query.getUrl
    end
    url
  end    
    
  def getIp()
    for query in @queries
        ip = query.getIp
    end
    ip
  end
 
  
  def getMax_time
    @max_time
  end
  
  def getMax_lock
    @max_lock
  end
  
  def getMin_time
    @min_time
  end
  
  def getMin_lock
    @min_lock
  end
  
  def getNumberQueries 
    @queries.length
  end
  
  def getMedianTime
    @queries.sort{ |a,b| a.getTime <=> b.getTime }[@queries.length / 2].getTime
  end
  
  def getMedianLock
    @queries.sort{ |a,b| a.getLock <=> b.getLock }[@queries.length / 2].getLock
  end
  
  def getAverageTime
    total = 0
    for query in @queries
      total = total + query.getTime
    end
    total / @queries.length
  end
  
  def getAverageLock
    total = 0
    for query in @queries
      total = total + query.getLock
    end
    total / @queries.length
  end
  
  def to_s
      "Max time: #{@max_time}, Max lock #{@max_lock}, Number of queries #{@queries.length} \n #{@sql}"
  end
   
  def display
    puts "#{@queries.length} Queries"
    puts "user: #{getUser}"      
    puts "url: #{getUrl}"
    puts "ip: #{getIp}"
    if @queries.length < 10 then
      
      @queries.sort!{ |a,b| a.getTime <=> b.getTime }
      print "Taking "
      @queries.each do |q|
        print "#{q.getTime} "
      end
      puts "seconds to complete"
      
      @queries.sort{ |a,b| a.getLock <=> b.getLock }
      print "Locking for "
      @queries.each do |q|
        print "#{q.getLock} "
      end
      puts "seconds"
    else
      puts "Taking #{@min_time} to #{@max_time} seconds to complete"
      puts "Locking for #{@min_lock} to #{@max_lock} seconds"    
    end
    
    puts "Average time: #{getAverageTime}, Median time #{getMedianTime}"
    puts "Average lock: #{getAverageLock}, Median lock #{getMedianLock}"

    puts 
    puts "#{@sql}"
  end
   
end

#
# Starts Here
#

begin
    file = File.new(logPath, "r")
    while (line = file.gets)
        # First line in the query header is the time in which the query happened
        if line[0,1] == '#'
          
          if line[0,7] == "# Time:" then  
            date = "#{line}".delete("#Time:").lstrip.chop
          
            # Ignore next line in the log (server info)
            line = file.gets
            sl = line.split(" ")
            user = sl[2]
            url = sl[4]
            ip = sl[5]
          else
            # puts "Found line missing Date info. Date set to 0"
            date = 0
          end
        
          # This line (3rd) has all the important info. Time, Lock etc.
          line = file.gets
          sl = line.split(" ")
          time = sl[2]
          lock = sl[4]
          sent = sl[6]
          rows = sl[8]
          
          # The next line is the sql query
          sql = file.gets
          if sql[0,3] == 'use' then
            # When a use statement has been passed as a part of the query the next line is the actual query
            sql = file.gets
          end
          
          # Some queries span multiple lines
          position = file.pos # Store the position
          while ((next_line = file.gets) && !(next_line =~ /^#/))
            position = file.pos
            sql += next_line
          end
          file.pos = position

          # Create and store query object
          # If it is more than one week ago or if it doesn't have a valid timestamp we ignore it
          if date != 0 and not (Date.strptime(date, '%y%m%d') < Date.jd((DateTime.now.jd)) - 8)
            query = Query.new(sql, date, time, lock, rows, sent, user, url, ip)
            queries.push(query)
          end
        else
          # puts "Ignoring line (This normally means the querys header is messed up)"
          # puts line
        end
    end
    file.close
    
    #
    # Go over all the query objects and group them in the appropriate QueryTotals object based on the SQL
    #
    for query in queries
        if queryTotals.has_key?(query.getNormalizedQuery) then
          qt = queryTotals.fetch(query.getNormalizedQuery)
          qt.addQuery(query)
        else
          qt = QueryTotal.new(query.getNormalizedQuery)
          qt.addQuery(query)
          queryTotals.store(query.getNormalizedQuery, qt)
        end
    end


    #
    # Sort the query totals by lock time and display the output
    #
    queryTotalsArray = queryTotals.values
    
    case orderBy
      when "lock"
        queryTotalsArray.sort! { |a,b| a.getMax_lock <=> b.getMax_lock }    
        #queryTotalsArray.reverse!
      when "time"
        queryTotalsArray.sort! { |a,b| a.getMax_time <=> b.getMax_time }    
        #queryTotalsArray.reverse!
      else
        queryTotalsArray.sort! { |a,b| a.getNumberQueries <=> b.getNumberQueries }    
        #queryTotalsArray.reverse!
    end
    
    puts
    for queryTotal in queryTotalsArray
      puts spacer
      queryTotal.display
    end
    
rescue => err
    puts "Exception: #{err}"
    err
end
