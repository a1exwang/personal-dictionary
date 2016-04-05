require 'net/http'
require 'json'

module Whats
  HOST = 'https://api.pearson.com'
  MP3_HOST = 'http://api.pearson.com'
  TMP_PATH = '/tmp/mydict'


  DICTIONARIES = {
      contemporary: 'ldoce5',
      en_cn: 'ldec',
      advanced_american: 'laad3',
      wordwise: 'wordwise',
      active_study: 'lasde'
  }

  def self.random_file_name(prefix = '', suffix = '')
    chars = ['a'..'z', 'A'..'Z', '0'..'9'].map(&:to_a).flatten
    ret = prefix
    30.times do
      ret += chars.sample
    end
    if suffix && suffix.size > 0
      ret += '.' + suffix
    end
    ret
  end

  def self.parse_pronunciation(pronunciations)
    ret = {}
    if pronunciations
      pronunciations.each do |p|
        audio = p['audio']
        ipa = p['ipa']
        bri = audio.find { |x| x['lang'] =~ /British/i }
        if bri
          ret[:bri_ipa] = ipa
          ret[:bri_url] = MP3_HOST + bri['url'] if bri['url']

        end
        ame = audio.find { |x| x['lang'] =~ /American/i }
        if ame
          ret[:ame_ipa] = ipa
          ret[:ame_url] = MP3_HOST + ame['url'] if ame['url']
        end
      end
    end
    ret
  end

  def self.word(w, dict = nil)
    dict ||= DICTIONARIES[:contemporary]
    first_time_limit = 10
    str = Net::HTTP.get(
        URI("#{MP3_HOST}/v2/dictionaries/#{dict}/entries?headword=#{w}&limit=#{first_time_limit}"))
    json = JSON.parse(str)
    json_results = json['results']
    return { status: :failed } if json_results.size <= 0
    total = json['total']
    results = []

    json_results.each do |result|
      word_entry = {}
      word_entry[:headword] = result['headword']
      word_entry[:part_of_speech] = result['part_of_speech']
      word_entry.merge!(parse_pronunciation(result['pronunciations']))
      if result['senses'] && result['senses'].size > 0
        sense = result['senses'].first
        if sense['definition']
          word_entry[:defs] = sense['definition'].join("\n")
        end
      end
      results << word_entry
    end
    results
  end

  def self.print_with_color(str, color)
    printf "\x1b[38;2;#{color[0]};#{color[1]};#{color[2]}m#{str}\x1b[0m"
  end

  def self.print_result(results)
    results.each_with_index do |r, i|
      print_with_color "#{i}. ", [255,255,0]
      print_with_color(r[:headword], [255,0,0])
      if r[:part_of_speech]
        print '('; print_with_color(r[:part_of_speech], [0,255,0]); puts ')'
      end
      if r[:bri_ipa]
        print_with_color "\u{1F50A} ", [255,255,0] if r[:bri_url]
        print 'BrE: '; print_with_color "/#{r[:bri_ipa]}/", [0, 255,255]
      end
      if r[:ame_ipa]
        print_with_color "   \u{1F50A} ", [255,255,0] if r[:ame_url]
        print 'NAmE: '; print_with_color "/#{r[:ame_ipa]}/", [0, 255,255]
      end
      puts
      if r[:defs]
        puts "definition: #{r[:defs]}"
      end
      puts
    end
  end
end