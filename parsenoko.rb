#!/usr/bin/ruby

    require 'rubygems'
    require 'nokogiri'

    list = []
    doc = Nokogiri::XML(File.open(ARGV[0], 'r'))

    # Find each dictionary item and loop through it
    doc.xpath('/plist/dict/dict/dict').each do |node|

      hash     = {}
      last_key = nil

      # Stuff the key value pairs in to hash.  We know a key is followed by
      # a value, so we'll just skip blank nodes, save the key, then when we
      # find the value, add it to the hash
      node.children.each do |child|

        next if child.blank? # Don't care about blank nodes

        if child.name == 'key'
          # Save off the key
          last_key = child.text
        else
          # Use the key we saved
          hash[last_key] = child.text
        end
      end

      list << hash # push on to our list
    end

    # Do something interesting with the list
    p list

